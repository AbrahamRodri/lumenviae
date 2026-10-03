defmodule LumenViae.Curation.Jobs.RecordRosaryClip do
  @moduledoc """
  Records one spoken Rosary clip (`LumenViae.Rosary.PrayerAudio`) in one
  voice and uploads it to its key. No database row: which clips exist is
  answered by S3 itself.

  Enqueued by `LumenViae.Curation.RosaryAudioGeneration`. Arguments: the
  clip's `kind` and `name`, the `voice` slug, the `key` it was enqueued
  for (unique while a job for it is waiting or running), a `label` and
  `force`.

  A clip's key carries a hash of its words and the voice's settings, so any
  object at the key is already right (`already_right: :exists` in
  `LumenViae.Audio.Recording`), and a clip whose wording has changed since
  it was enqueued has a different key now. Such a job is cancelled rather
  than left to record words nobody asked for: run the task again and it
  enqueues the new wording.
  """
  use Oban.Worker,
    queue: :elevenlabs,
    max_attempts: 5,
    unique: [keys: [:key], states: :incomplete, period: :infinity]

  alias LumenViae.Audio.Recording
  alias LumenViae.Curation.AudioJobs
  alias LumenViae.Rosary.{PrayerAudio, Voices}

  @doc "The job for `clip` in `voice`."
  def new_for(%PrayerAudio.Clip{} = clip, %Voices.Voice{} = voice, opts \\ []) do
    new(%{
      kind: to_string(clip.kind),
      name: clip.name,
      voice: voice.slug,
      key: PrayerAudio.s3_key(voice, clip),
      label: "#{voice.slug} #{clip.kind} #{clip.name}",
      force: Keyword.get(opts, :force, false)
    })
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)

  # See NarrateMeditation: from 30 seconds to about eight minutes.
  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}), do: 30 * Integer.pow(2, attempt - 1)

  @impl Oban.Worker
  def perform(%Oban.Job{args: args} = job) do
    with {:ok, voice} <- fetch_voice(args["voice"]),
         {:ok, clip} <- fetch_clip(args["kind"], args["name"]),
         :ok <- same_key(voice, clip, args["key"]) do
      clip
      |> PrayerAudio.speech_text()
      |> Recording.record(voice, args["key"],
        job_id: job.id,
        orphaned: Recording.orphaned?(job),
        already_right: :exists,
        force: args["force"] == true
      )
      |> finish(job)
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

  defp fetch_clip(kind, name) do
    clip =
      case atom_kind(kind) do
        nil -> nil
        kind -> [kind] |> PrayerAudio.clips() |> Enum.find(&(&1.name == name))
      end

    if clip, do: {:ok, clip}, else: {:cancel, "#{kind} #{name} is no longer in the catalogue"}
  end

  # The job stores the clip's own kind (:prayer, as "prayer"); the
  # catalogue's slugs are plural, so the atom is found among its values.
  defp atom_kind(kind) do
    Enum.find(Map.values(PrayerAudio.kinds()), &(to_string(&1) == kind))
  end

  defp same_key(voice, clip, key) do
    if PrayerAudio.s3_key(voice, clip) == key,
      do: :ok,
      else:
        {:cancel, "the wording or the voice changed after #{key} was queued; run the task again"}
  end

  defp finish({:ok, :recorded, characters}, job),
    do: report(job, :recorded, "recorded #{characters} characters to #{job.args["key"]}", :ok)

  defp finish({:ok, :already_recorded}, job),
    do:
      report(job, :already_recorded, "already recorded at #{job.args["key"]}, nothing spent", :ok)

  defp finish({:retry, reason}, job) do
    status = if job.attempt >= job.max_attempts, do: :failed, else: :retrying
    report(job, status, reason, {:error, reason})
  end

  defp finish({:cancel, reason}, job), do: report(job, :failed, reason, {:cancel, reason})

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
