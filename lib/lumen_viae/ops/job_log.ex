defmodule LumenViae.Ops.JobLog do
  @moduledoc """
  One error line for every job attempt that fails, beside Oban's own
  info-level line for every job event (`LumenViae.Application`), so
  `fly logs` filtered on `[error]` shows the failures alone:

      job_failed worker=LumenViae.Curation.Jobs.NarrateMeditation queue=elevenlabs id=42 attempt=2/5 state=failure error=...

  `state` is Oban's: `failure` (it runs again while attempts remain),
  `discard` (out of attempts) or `cancelled`. The error is its first line, cut short;
  the arguments are left to Oban's own line.
  """
  require Logger

  def attach do
    :telemetry.attach(
      "lumen-viae-job-log",
      [:oban, :job, :exception],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @doc false
  def handle_event([:oban, :job, :exception], _measurements, metadata, _config) do
    job = metadata.job

    Logger.error(
      "job_failed worker=#{job.worker} queue=#{job.queue} id=#{job.id} " <>
        "attempt=#{job.attempt}/#{job.max_attempts} state=#{metadata[:state]} " <>
        "error=#{describe(metadata[:reason])}"
    )
  end

  defp describe(exception) when is_exception(exception),
    do: first_line(inspect(exception.__struct__) <> ": " <> Exception.message(exception))

  defp describe(reason), do: reason |> inspect(limit: 5) |> first_line()

  defp first_line(text), do: text |> String.split("\n", parts: 2) |> hd() |> String.slice(0, 200)
end
