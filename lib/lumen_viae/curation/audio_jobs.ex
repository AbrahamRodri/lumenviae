defmodule LumenViae.Curation.AudioJobs do
  @moduledoc """
  The narration jobs as a group: enqueueing them in batches, reporting
  their progress, and waiting for a batch to finish.

  Two workers record audio, both on the `elevenlabs` queue:

    * `LumenViae.Curation.Jobs.NarrateMeditation` - one meditation in one
      voice, enqueued by the CSV import and by audio regeneration
    * `LumenViae.Curation.Jobs.RecordRosaryClip` - one spoken Rosary clip
      in one voice, enqueued by `LumenViae.Curation.RosaryAudioGeneration`

  Both record through `LumenViae.Audio.Recording`, which is what keeps a
  retry or a duplicate from paying ElevenLabs twice, and both are unique by
  S3 key while a job for that key is waiting or running.

  ## Batches

  Every enqueue names a batch: one import, one regeneration, one run of the
  spoken Rosary task. The batch id is in each job's `meta` (not its args,
  so it plays no part in uniqueness), which is how `progress/1` counts a
  batch from the jobs table, through the GIN index Oban keeps on `meta`.

  ## Live progress

  Each job broadcasts on `LumenViae.PubSub` as it finishes, on its batch's
  topic (`subscribe/1`) and on a topic for every audio job
  (`subscribe_all/0`, which the spoken Rosary screen uses). The message is
  `{:audio_job, event}`, where `event` is a map with `:batch`, `:worker`,
  `:key`, `:label`, `:status` (`:recorded`, `:already_recorded`,
  `:retrying`, `:failed`) and `:message`. The production machines are
  clustered, so a LiveView hears a job that ran on the other machine.

  ## Where jobs run

  Wherever the app's Oban runs its `elevenlabs` queue: the web app in
  production, or the mix task's own node on a laptop. A release task run
  with `bin/lumen_viae eval` starts no queues; it enqueues through
  `start_inserter/0` and the running app does the work.
  """

  import Ecto.Query, only: [from: 2]

  alias LumenViae.Repo

  @pubsub LumenViae.PubSub
  @all_topic "audio_jobs"
  @incomplete ~w(available scheduled executing retryable suspended)
  @workers [
    "LumenViae.Curation.Jobs.NarrateMeditation",
    "LumenViae.Curation.Jobs.RecordRosaryClip"
  ]

  @doc "A new batch id."
  def new_batch,
    do: "batch-" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))

  @doc """
  `opts` with a `:batch`: the one given, or a new one when it is missing
  or nil.
  """
  def with_batch(opts) do
    if opts[:batch], do: opts, else: Keyword.put(opts, :batch, new_batch())
  end

  @doc """
  Inserts a job built by a worker's `new/2`, tagged with `batch`. Returns
  `{:ok, :queued}`, `{:ok, :already_queued}` when a job for the same key is
  already waiting or running, or `{:error, reason}`.
  """
  def enqueue(%Ecto.Changeset{} = changeset, batch) do
    meta = Map.merge(Ecto.Changeset.get_field(changeset, :meta) || %{}, %{"batch" => batch})

    case changeset |> Ecto.Changeset.put_change(:meta, meta) |> Oban.insert() do
      {:ok, %Oban.Job{conflict?: true}} -> {:ok, :already_queued}
      {:ok, _job} -> {:ok, :queued}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Subscribes the caller to one batch's events."
  def subscribe(batch), do: Phoenix.PubSub.subscribe(@pubsub, topic(batch))

  @doc "Unsubscribes the caller from one batch's events."
  def unsubscribe(batch), do: Phoenix.PubSub.unsubscribe(@pubsub, topic(batch))

  @doc "Subscribes the caller to every audio job's events."
  def subscribe_all, do: Phoenix.PubSub.subscribe(@pubsub, @all_topic)

  @doc """
  Broadcasts a finished (or retrying) job. Called by the workers; `event`
  carries `:key`, `:label`, `:status` and `:message`.
  """
  def broadcast(%Oban.Job{} = job, event) do
    event =
      Map.merge(event, %{
        batch: job.meta["batch"],
        worker: job.worker,
        attempt: job.attempt,
        max_attempts: job.max_attempts
      })

    if event.batch, do: Phoenix.PubSub.broadcast(@pubsub, topic(event.batch), {:audio_job, event})
    Phoenix.PubSub.broadcast(@pubsub, @all_topic, {:audio_job, event})
    :ok
  end

  defp topic(batch), do: "audio_jobs:" <> batch

  @doc """
  A batch's jobs counted by outcome:
  `%{total, pending, completed, failed}`, where `failed` is cancelled or
  discarded. One grouped count on the jobs table.
  """
  def progress(batch) do
    counts =
      from(j in Oban.Job,
        where: fragment("? @> ?", j.meta, ^%{"batch" => batch}),
        group_by: j.state,
        select: {j.state, count(j.id)}
      )
      |> Repo.all()
      |> Map.new()

    pending = @incomplete |> Enum.map(&Map.get(counts, &1, 0)) |> Enum.sum()
    completed = Map.get(counts, "completed", 0)
    failed = Map.get(counts, "cancelled", 0) + Map.get(counts, "discarded", 0)

    %{total: pending + completed + failed, pending: pending, completed: completed, failed: failed}
  end

  @doc """
  The batch's failed jobs, each as `{label, last error}`, for a summary.
  """
  def failures(batch) do
    from(j in Oban.Job,
      where: fragment("? @> ?", j.meta, ^%{"batch" => batch}),
      where: j.state in ["cancelled", "discarded"],
      order_by: j.id,
      select: {j.args, j.errors}
    )
    |> Repo.all()
    |> Enum.map(fn {args, errors} ->
      error = errors |> List.last() |> Kernel.||(%{}) |> Map.get("error", "no error recorded")
      {args["label"] || args["key"], reason(error)}
    end)
  end

  # Oban keeps a cancelled or failed job's error as the exception it
  # formatted, "** (Oban.PerformError) Worker failed with {:cancel, "..."}";
  # the reason the worker gave is the quoted part.
  defp reason(error) do
    case Regex.run(~r/failed with \{:(?:cancel|error), "(.*)"\}\s*$/s, error) do
      [_, reason] -> String.replace(reason, ~S(\"), ~S("))
      nil -> error
    end
  end

  @doc """
  The audio jobs not finished yet, across every batch, newest first:
  `[%{worker, key, label, state}]`. For a screen opening while a run is
  under way.
  """
  def in_flight do
    from(j in Oban.Job,
      where: j.worker in ^@workers and j.state in ^@incomplete,
      order_by: [desc: j.id],
      select: %{worker: j.worker, args: j.args, state: j.state}
    )
    |> Repo.all()
    |> Enum.map(
      &%{worker: &1.worker, key: &1.args["key"], label: &1.args["label"], state: &1.state}
    )
  end

  @doc """
  Blocks until no job in `batch` is waiting or running, printing as it
  goes, and returns the batch's final counts (`progress/1`).

  For the mix tasks and release tasks, which have a person (or a log file)
  waiting on them; nothing else should wait on a batch. Subscribe to the
  batch (`subscribe/1`) before enqueueing, and each job is printed as it
  finishes; a job that ran on a node this one cannot hear (a release task
  run with `eval` is not part of the cluster) is still counted, from the
  jobs table, which is read after each event and every `:interval`
  milliseconds (default five seconds) otherwise.

  `print` takes one line of output. At the end the failed jobs are printed
  with their last error.
  """
  def follow(batch, print, opts \\ []) do
    interval = Keyword.get(opts, :interval, 5_000)
    counts = progress(batch)

    if counts.pending == 0 do
      drain_events(batch, print)
      finish(batch, counts, print)
    else
      receive do
        {:audio_job, %{batch: ^batch} = event} -> print_event(event, print)
      after
        interval ->
          print.("... #{counts.pending} of #{counts.total} recording(s) still to finish")
      end

      follow(batch, print, opts)
    end
  end

  defp drain_events(batch, print) do
    receive do
      {:audio_job, %{batch: ^batch} = event} ->
        print_event(event, print)
        drain_events(batch, print)
    after
      0 -> :ok
    end
  end

  defp print_event(%{status: status, label: label, message: message}, print) do
    prefix =
      case status do
        :recorded -> "REC  "
        :already_recorded -> "SKIP "
        :retrying -> "RETRY"
        :failed -> "FAIL "
      end

    print.("#{prefix} #{label}: #{message}")
  end

  defp finish(batch, counts, print) do
    Enum.each(failures(batch), fn {label, error} -> print.("FAILED #{label}: #{error}") end)

    print.(
      "Recordings: #{counts.completed} finished, #{counts.failed} failed, of #{counts.total}"
    )

    counts
  end

  @doc """
  For a mix task whose own node runs the queue: raises this node's
  `elevenlabs` limit to `concurrency` (default 3; the queue's configured
  limit is sized for production's two machines, and a laptop running the
  task is one), then `follow/3`s the batch to the terminal.
  """
  def wait_here(batch, concurrency \\ nil) do
    Oban.scale_queue(queue: :elevenlabs, limit: concurrency || 3, local_only: true)
    follow(batch, &IO.puts/1)
  end

  @doc """
  Makes sure an Oban instance is running to insert jobs through, for a
  release task run with `eval`, where the application is not started. The
  instance runs no queues, no plugins and never leads: it only writes jobs
  into the table, and the running app picks them up. Needs the repo
  started (`Ecto.Migrator.with_repo/2`).
  """
  def start_inserter do
    # Oban's own application holds the registry whereis/1 reads, and eval
    # has not started it.
    {:ok, _apps} = Application.ensure_all_started(:oban)

    case Oban.whereis(Oban) do
      nil ->
        config =
          :lumen_viae
          |> Application.fetch_env!(Oban)
          |> Keyword.merge(
            queues: [],
            plugins: false,
            stager: false,
            peer: false,
            notifier: Oban.Notifiers.PG
          )

        {:ok, _pid} = Oban.start_link(config)
        :ok

      _pid ->
        :ok
    end
  end
end
