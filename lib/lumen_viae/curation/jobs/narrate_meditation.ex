defmodule LumenViae.Curation.Jobs.NarrateMeditation do
  @moduledoc """
  Records one meditation in one voice and puts it on record: the ElevenLabs
  call, the upload to `voices/<slug>/<filename>`, the narration row, and
  the meditation's `audio_url` if it has none yet.

  Enqueued by `LumenViae.Curation.CsvImport` (one job per new meditation
  and voice) and `LumenViae.Curation.AudioRegeneration`, through `new/2`
  and `LumenViae.Curation.AudioJobs.enqueue/2`. The text is read from the
  meditation when the job runs, so it records what the meditation says
  then.

  Arguments: `meditation_id`, `voice` (a slug), `filename`, `key` (the S3
  key, which the job is unique by while one is waiting or running),
  `label` (for progress and Oban Web), `force`, and `keep_existing`.

  An object already at the key is "already right" when it carries this
  recording's fingerprint. With `keep_existing` (what `regenerate_audio
  --only-missing` enqueues), any object there counts, including one
  recorded before fingerprints existed, which has no metadata to compare:
  filling a gap must never pay to replace a recording that is there.

  Paying once is `LumenViae.Audio.Recording`'s job; this module turns its
  answer into Oban's. `{:retry, _}` is an error, retried with backoff
  while attempts remain, and `{:cancel, _}` cancels the job, because
  trying again might pay ElevenLabs for the same clip twice.

  Runs as the system, with `authorize?: false`: whoever enqueued it (an
  admin through the console, or an operator's shell) was authorized then,
  and the job only finishes what they asked for. See docs/ARCHITECTURE.md,
  "Who may do what".
  """
  use Oban.Worker,
    queue: :elevenlabs,
    max_attempts: 5,
    unique: [keys: [:key], states: :incomplete, period: :infinity]

  alias LumenViae.Audio.{Pipeline, Recording}
  alias LumenViae.Curation.AudioJobs
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Voices

  # The system, finishing what an authorized caller enqueued.
  @system [authorize?: false]

  @doc """
  The job for `meditation` in `voice`, recorded to that voice's key for
  `filename`.
  """
  def new_for(meditation, %Voices.Voice{} = voice, filename, opts \\ []) do
    label = "#{voice.slug} narration of meditation #{meditation.id}"

    new(%{
      meditation_id: meditation.id,
      voice: voice.slug,
      filename: filename,
      key: Voices.narration_key(voice, filename),
      label: label,
      force: Keyword.get(opts, :force, false),
      keep_existing: Keyword.get(opts, :keep_existing, false)
    })
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)

  # A 429 or a 5xx is ElevenLabs saying "not now"; the next attempt waits
  # longer each time, from 30 seconds to about eight minutes.
  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}), do: 30 * Integer.pow(2, attempt - 1)

  @impl Oban.Worker
  def perform(%Oban.Job{args: args} = job) do
    with {:ok, voice} <- fetch_voice(args["voice"]),
         {:ok, meditation} <- fetch_meditation(args["meditation_id"]) do
      text = Pipeline.speech_text(meditation.content, meditation.tts_annotations, voice)

      text
      |> Recording.record(voice, args["key"],
        job_id: job.id,
        force: args["force"] == true,
        already_right: if(args["keep_existing"] == true, do: :exists, else: :same_fingerprint)
      )
      |> finish(job, meditation, args)
    else
      {:cancel, reason} -> report(job, :failed, reason, {:cancel, reason})
    end
  end

  defp fetch_voice(slug) do
    case Voices.get(slug) do
      nil -> {:cancel, "voice #{slug} is no longer configured"}
      voice -> {:ok, voice}
    end
  end

  defp fetch_meditation(id) do
    case Rosary.get_meditation(id, @system) do
      {:ok, meditation} -> {:ok, meditation}
      {:error, _not_found} -> {:cancel, "meditation #{id} no longer exists"}
    end
  end

  defp finish({:ok, outcome}, job, meditation, args),
    do: put_on_record(outcome, job, meditation, args)

  defp finish({:ok, :recorded, characters}, job, meditation, args),
    do: put_on_record({:recorded, characters}, job, meditation, args)

  defp finish({:retry, reason}, job, _meditation, _args) do
    status = if job.attempt >= job.max_attempts, do: :failed, else: :retrying
    report(job, status, reason, {:error, reason})
  end

  defp finish({:cancel, reason}, job, _meditation, _args),
    do: report(job, :failed, reason, {:cancel, reason})

  # The object is in S3 by now, paid for once. A failure from here on is
  # the database's, and a retry finds its own upload and comes straight
  # back here without calling ElevenLabs.
  defp put_on_record(outcome, job, meditation, args) do
    with {:ok, _} <- Rosary.record_narration(meditation, args["voice"], args["key"], @system),
         {:ok, _} <- ensure_audio_url(meditation, args["filename"]) do
      {status, message} =
        case outcome do
          {:recorded, characters} ->
            {:recorded, "recorded #{characters} characters to #{args["key"]}"}

          :already_recorded ->
            {:already_recorded, "already recorded at #{args["key"]}, nothing spent"}
        end

      report(job, status, message, :ok)
    else
      {:error, error} ->
        reason = "recorded #{args["key"]} but could not put it on record: #{describe(error)}"
        finish({:retry, reason}, job, meditation, args)
    end
  end

  # The import creates a meditation without an audio_url and leaves the
  # first finished recording to set it, so a meditation never claims audio
  # that is not there yet.
  defp ensure_audio_url(%{audio_url: filename} = meditation, filename), do: {:ok, meditation}

  defp ensure_audio_url(%{audio_url: current} = meditation, filename) when current in [nil, ""],
    do: Rosary.update_meditation(meditation, %{audio_url: filename}, @system)

  defp ensure_audio_url(meditation, _filename), do: {:ok, meditation}

  defp describe(%Ash.Error.Invalid{} = error), do: Rosary.error_summary(error)
  defp describe(error) when is_exception(error), do: Exception.message(error)
  defp describe(error), do: inspect(error)

  defp report(job, status, message, result) do
    AudioJobs.broadcast(job, %{
      key: job.args["key"],
      label: job.args["label"],
      status: status,
      message: message
    })

    result
  end
end
