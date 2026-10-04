defmodule LumenViae.Ops.Jobs do
  @moduledoc """
  The job queues from the jobs table: what each queue holds, what has
  failed lately, what the crontab will run next and when it last did, and
  the operator's hands on them (retry, cancel, run a scheduled job now).

  Counts read `oban_jobs` directly, grouped by queue and state, through
  the compound index every Oban fetch already uses. The pruner keeps a
  week of finished jobs, so "completed" means "in the last seven days".

  ## The schedule

  The production crontab is defined once in `config/config.exs` and stored
  twice: as Oban's `cron: [crontab: ...]`, which Oban runs, and as
  `:lumen_viae, :scheduled_jobs`, which this module reads. Development
  empties the first and not the second, so the System screen and
  `mix lumen_viae.jobs run` still know the schedule on a laptop, and say
  that it is not running there. AshOban adds each trigger's scheduler to
  Oban's crontab at boot; those are read from the resources themselves
  (`trigger_schedulers/0`), so they are listed wherever the app is.
  """

  import Ecto.Query, only: [from: 2]

  alias LumenViae.Repo
  alias Oban.Cron.Expression

  @states ~w(available scheduled executing retryable completed discarded cancelled suspended)
  @failed ~w(retryable discarded cancelled)

  @doc "Every state a job can be in, in Oban's order."
  def states, do: @states

  @doc """
  One row per queue, configured or holding jobs:
  `%{queue:, limit:, counts: %{state => n}, oldest_available_at:}`.
  `limit` is nil for a queue this machine does not run.
  """
  def queues do
    limits = configured_queues()

    counts =
      Repo.all(
        from j in Oban.Job,
          group_by: [j.queue, j.state],
          select: {j.queue, j.state, count(j.id)}
      )

    oldest =
      Repo.all(
        from j in Oban.Job,
          where: j.state == "available",
          group_by: j.queue,
          select: {j.queue, min(j.scheduled_at)}
      )
      |> Map.new()

    by_queue = Enum.group_by(counts, &elem(&1, 0), fn {_queue, state, n} -> {state, n} end)

    (Map.keys(limits) ++ Map.keys(by_queue))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn queue ->
      %{
        queue: queue,
        limit: Map.get(limits, queue),
        counts: Map.new(Map.get(by_queue, queue, [])),
        oldest_available_at: Map.get(oldest, queue)
      }
    end)
  end

  @doc """
  The most recent jobs that are waiting to retry, were discarded or were
  cancelled, newest first, each with the first line of its last error.
  """
  def recent_failures(limit \\ 10) do
    Repo.all(
      from j in Oban.Job,
        where: j.state in @failed,
        order_by: [desc: j.attempted_at, desc: j.id],
        limit: ^limit
    )
    |> Enum.map(&summarize/1)
  end

  @doc """
  The production crontab, each entry with when it runs next and how its
  last run went: `%{expression:, worker:, next_at:, last_run:, running_here?:}`.
  `next_at` is nil for `@reboot`. `running_here?` is false where Oban's
  running crontab lacks the entry (the configured ones in development, and
  everything in the suite).
  """
  def schedule(now \\ DateTime.utc_now()) do
    running = running_crontab()

    Enum.map(scheduled_jobs(), fn {expression, worker} ->
      %{
        expression: expression,
        worker: inspect(worker),
        next_at: next_at(expression, now),
        last_run: last_run(worker),
        running_here?: {expression, worker} in running
      }
    end)
  end

  @doc "The module names of the crontab's workers, the only ones `enqueue_scheduled/1` runs."
  def scheduled_workers do
    scheduled_jobs() |> Enum.map(fn {_expression, worker} -> inspect(worker) end) |> Enum.uniq()
  end

  @doc """
  The newest job of `worker` (a module, or its name), or nil:
  `%{id:, state:, attempt:, max_attempts:, inserted_at:, attempted_at:,
  completed_at:, error:}`.
  """
  def last_run(worker) do
    name = if is_atom(worker), do: inspect(worker), else: worker

    from(j in Oban.Job, where: j.worker == ^name, order_by: [desc: j.id], limit: 1)
    |> Repo.one()
    |> case do
      nil -> nil
      job -> summarize(job)
    end
  end

  @doc "One job's summary by id, as `last_run/1` gives it, or nil."
  def get(id) when is_integer(id) do
    case Repo.get(Oban.Job, id) do
      nil -> nil
      job -> summarize(job)
    end
  end

  @doc """
  Enqueues a crontab worker, by module name, with no arguments, as the
  crontab would. `{:error, :not_scheduled}` for any other name.
  """
  def enqueue_scheduled(name) when is_binary(name) do
    case Enum.find(scheduled_jobs(), fn {_expression, worker} -> inspect(worker) == name end) do
      {_expression, worker} -> Oban.insert(worker.new(%{}))
      nil -> {:error, :not_scheduled}
    end
  end

  @doc """
  Makes failed jobs available to run again, now. `filter` is one of
  `id: 42`, `queue: "elevenlabs"` or `worker: "LumenViae....Worker"`; the
  last two retry every job of theirs that is retryable or discarded (a
  cancelled job is left alone: somebody, or the job itself, decided).
  Answers `{:ok, count}`.
  """
  def retry(id: id) when is_integer(id) do
    case Repo.get(Oban.Job, id) do
      nil -> {:error, :not_found}
      _job -> Oban.retry_job(id) |> then(fn :ok -> {:ok, 1} end)
    end
  end

  def retry([{field, value}]) when field in [:queue, :worker] and is_binary(value) do
    query = from j in Oban.Job, where: j.state in ["retryable", "discarded"]

    query =
      case field do
        :queue -> from j in query, where: j.queue == ^value
        :worker -> from j in query, where: j.worker == ^value
      end

    Oban.retry_all_jobs(query)
  end

  @doc "Cancels one job. One already finished is left as it is."
  def cancel(id) when is_integer(id) do
    case Repo.get(Oban.Job, id) do
      nil -> {:error, :not_found}
      _job -> Oban.cancel_job(id)
    end
  end

  defp summarize(job) do
    %{
      id: job.id,
      worker: job.worker,
      queue: job.queue,
      state: job.state,
      attempt: job.attempt,
      max_attempts: job.max_attempts,
      inserted_at: job.inserted_at,
      attempted_at: job.attempted_at,
      completed_at: job.completed_at,
      error: last_error(job.errors)
    }
  end

  defp last_error([]), do: nil
  defp last_error(nil), do: nil

  defp last_error(errors) do
    errors
    |> List.last()
    |> Map.get("error", "")
    |> String.split("\n", parts: 2)
    |> hd()
    |> String.slice(0, 300)
  end

  defp next_at("@reboot", _now), do: nil

  defp next_at(expression, now) do
    expression |> Expression.parse!() |> Expression.next_at(now)
  end

  defp scheduled_jobs,
    do: Application.get_env(:lumen_viae, :scheduled_jobs, []) ++ trigger_schedulers()

  @doc """
  The AshOban trigger schedulers in every domain, as `{cron, scheduler}`
  crontab entries, the way AshOban adds them to Oban's crontab.
  """
  def trigger_schedulers do
    for domain <- Application.get_env(:lumen_viae, :ash_domains, []),
        resource <- Ash.Domain.Info.resources(domain),
        AshOban in Spark.extensions(resource),
        trigger <- AshOban.Info.oban_triggers(resource),
        is_binary(trigger.scheduler_cron) and not is_nil(trigger.scheduler),
        do: {trigger.scheduler_cron, trigger.scheduler}
  end

  # What this machine's Oban is actually running: the Cron plugin's
  # crontab, which holds only AshOban's schedulers in development, and is
  # absent in the suite (testing: :manual drops every plugin) and in a
  # release shell's inserter.
  defp running_crontab do
    Oban.config().plugins
    |> Enum.find_value([], fn
      {Oban.Cron, opts} -> opts |> Keyword.get(:crontab, []) |> Enum.map(&entry/1)
      _other -> nil
    end)
  rescue
    _not_running -> []
  end

  # A crontab entry without its options: AshOban adds `{cron, worker, opts}`.
  defp entry({expression, worker, _opts}), do: {expression, worker}
  defp entry({expression, worker}), do: {expression, worker}

  # The queues and their limits, from the running Oban where it runs any
  # (a mix task may have raised a limit), else from the config (the suite's
  # manual mode, and a release shell's inserter, run none).
  defp configured_queues do
    running =
      try do
        Oban.config().queues
      rescue
        _not_running -> []
      end

    queues =
      if running in [nil, []],
        do: Application.get_env(:lumen_viae, Oban, []) |> Keyword.get(:queues, []),
        else: running

    Map.new(queues || [], fn {queue, opts} ->
      limit = if is_list(opts), do: opts[:limit], else: opts
      {to_string(queue), limit}
    end)
  end
end
