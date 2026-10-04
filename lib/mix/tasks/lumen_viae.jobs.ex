defmodule Mix.Tasks.LumenViae.Jobs do
  @shortdoc "Shows the job queues, and retries, cancels or runs jobs, locally"
  @moduledoc """
  The job queues from a terminal: the same figures as the console's System
  screen, and the operator's hands on them.

      mix lumen_viae.jobs                      # the queues, by state
      mix lumen_viae.jobs failures --limit 20  # what failed lately, and why
      mix lumen_viae.jobs schedule             # the crontab, next and last runs
      mix lumen_viae.jobs retry --id 42
      mix lumen_viae.jobs retry --queue elevenlabs
      mix lumen_viae.jobs retry --worker LumenViae.Office.Jobs.WarmCache
      mix lumen_viae.jobs cancel --id 42
      mix lumen_viae.jobs run Office.Jobs.WarmCache

  `retry --queue` and `retry --worker` make every retryable or discarded
  job of theirs available again; a cancelled job is left alone. `run`
  enqueues one of the crontab's workers now (the `LumenViae.` prefix may be
  left off), and only those, then waits up to five minutes for it to finish
  and says how it went.

  This starts the app, so its own node runs the queues: a job made
  available here runs here, against the local database (`DEV_DATABASE`
  picks a copy). For production, the same acts are `LumenViae.Release`
  functions run from a shell on Fly (docs/PROD_ACCESS.md):

      fly ssh console -C "/app/bin/lumen_viae rpc 'LumenViae.Release.jobs_summary()'"
  """
  use Mix.Task

  alias LumenViae.Ops
  alias LumenViae.Ops.Report

  @requirements ["app.start"]

  # Long enough for the Office warm against a cold engine; a job still
  # running after it is reported as it stands and carries on in the
  # database for whichever node runs its queue next.
  @wait_ms :timer.minutes(5)
  @poll_ms 1_000

  @impl Mix.Task
  def run(args) do
    {opts, argv, invalid} =
      OptionParser.parse(args,
        strict: [id: :integer, queue: :string, worker: :string, limit: :integer]
      )

    if invalid != [], do: Mix.raise("Invalid options: #{inspect(invalid)}")

    command(argv, opts)
  rescue
    error in Postgrex.Error ->
      if error.postgres[:code] == :undefined_table,
        do: Mix.raise("The jobs table does not exist in this database: run `mix ash.migrate`."),
        else: reraise(error, __STACKTRACE__)
  end

  defp command(argv, _opts) when argv in [[], ["stats"]], do: Mix.shell().info(Report.queues())

  defp command(["failures"], opts),
    do: Mix.shell().info(Report.failures(Ops.recent_failures(opts[:limit] || 10)))

  defp command(["schedule"], _opts), do: Mix.shell().info(Report.schedule(Ops.schedule()))
  defp command(["retry"], opts), do: retry(opts)
  defp command(["cancel"], opts), do: cancel(opts)
  defp command(["run", worker], _opts), do: run_scheduled(worker)

  defp command(argv, _opts),
    do: Mix.raise("Unknown command #{inspect(argv)}. See `mix help lumen_viae.jobs`.")

  defp retry(opts) do
    filter =
      case Keyword.take(opts, [:id, :queue, :worker]) do
        [single] -> [single]
        _none_or_many -> Mix.raise("retry takes exactly one of --id, --queue or --worker")
      end

    case Ops.retry_jobs(filter) do
      {:ok, count} -> Mix.shell().info("#{count} job(s) made available again.")
      {:error, :not_found} -> Mix.raise("No job with that id.")
    end
  end

  defp cancel(opts) do
    id = opts[:id] || Mix.raise("cancel takes --id")

    case Ops.cancel_job(id) do
      :ok -> Mix.shell().info("Job #{id} cancelled (one already finished is left as it was).")
      {:error, :not_found} -> Mix.raise("No job with that id.")
    end
  end

  defp run_scheduled(worker) do
    worker =
      if String.starts_with?(worker, "LumenViae."), do: worker, else: "LumenViae." <> worker

    case Ops.run_scheduled_job(worker, authorize?: false) do
      {:ok, id} ->
        Mix.shell().info("Queued #{worker} as job #{id}. Waiting for it to finish...")
        Mix.shell().info(Report.job_status(wait_for(id, @wait_ms)))

      {:error, _error} ->
        Mix.raise(
          "#{worker} is not in the crontab. Scheduled: #{Enum.join(Ops.scheduled_workers(), ", ")}"
        )
    end
  end

  defp wait_for(id, remaining) do
    job = Ops.job(id)

    if job.state in ~w(completed discarded cancelled retryable) or remaining <= 0 do
      job
    else
      Process.sleep(@poll_ms)
      wait_for(id, remaining - @poll_ms)
    end
  end
end
