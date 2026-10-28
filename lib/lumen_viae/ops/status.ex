defmodule LumenViae.Ops.Status do
  @moduledoc """
  What `GET /ops/status` answers: a deeper look than `/healthz`, for an
  agent or a person checking production after a deploy. The release and
  commit, whether the database answers, whether S3 can sign a link and
  reach the audio bucket, the Office engine, and the job queues with their
  most recent failures.

  It names no key, URL, address or argument: a failure is its worker,
  queue, state and the first line of its error, cut short. Even so it is
  not public; `LumenViaeWeb.OpsStatusController` asks for a token.
  """
  alias LumenViae.Ops.{Health, Jobs, Probes}
  alias LumenViae.Storage.S3

  @error_length 160

  def snapshot do
    health = Health.check()

    %{
      version: health.version,
      commit: health.commit,
      checks: %{
        database: %{status: status(health.db), detail: "SELECT 1"},
        s3_signing: s3_signing(),
        s3: probe(:s3),
        office_engine: probe(:office_engine),
        geolocation: probe(:geolocation),
        elevenlabs: probe(:elevenlabs)
      },
      jobs: Enum.map(Jobs.queues(), &queue/1),
      recent_failures: Enum.map(Jobs.recent_failures(10), &failure/1)
    }
  end

  defp status("ok"), do: :ok
  defp status(_error), do: :error

  # Signing is local, with the credentials; a link that signs proves the
  # keys are there, and the S3 probe proves they reach the bucket.
  defp s3_signing do
    case S3.generate_presigned_url("ops/probe", expires_in: 60) do
      {:ok, _url} -> %{status: :ok, detail: "a link signs"}
      {:error, :missing_credentials} -> %{status: :off, detail: "no credentials"}
      {:error, reason} -> %{status: :error, detail: inspect(reason, limit: 5)}
    end
  end

  defp probe(name), do: name |> Probes.run() |> Map.take([:status, :detail, :ms])

  defp queue(%{queue: queue, counts: counts}) do
    states = ~w(available scheduled executing retryable discarded cancelled)
    Map.new(states, &{&1, Map.get(counts, &1, 0)}) |> Map.put("queue", queue)
  end

  defp failure(job) do
    %{
      worker: job.worker,
      queue: job.queue,
      state: job.state,
      attempt: job.attempt,
      max_attempts: job.max_attempts,
      attempted_at: job.attempted_at,
      error: job.error && String.slice(first_line(job.error), 0, @error_length)
    }
  end

  defp first_line(text), do: LumenViae.Ops.ErrorLine.summary(text)
end
