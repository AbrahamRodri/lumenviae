defmodule LumenViae.Audio.Recording do
  @moduledoc """
  Records one clip with ElevenLabs and uploads it to its S3 key, at most
  once. Every narration job goes through `record/4`, because an ElevenLabs
  call costs money and a job can be retried, enqueued twice, or rescued
  after a crash.

  ## How a clip is never paid for twice

  Before anything is spent, the key is asked what is already there (one
  HEAD, `LumenViae.Storage.S3.audio_metadata/2`), and the upload records
  two things in the object's metadata: the job that recorded it, and a
  fingerprint of exactly what was spoken and how (`fingerprint/2`). So:

    * **A retry of the same job** finds its own job id on the object and
      stops: the clip was paid for and uploaded on an earlier attempt, and
      only the bookkeeping after it failed.
    * **A duplicate enqueue** is mostly stopped by the jobs' uniqueness
      (one job per key while one is waiting or running). One enqueued
      after the first finished finds an object that is already right and
      stops: for a meditation narration that is a matching fingerprint;
      for a spoken Rosary clip, whose key carries a hash of its text,
      any object at the key.
    * **A failure ElevenLabs may have charged for is never retried
      automatically.** `LumenViae.Audio.ElevenLabs` sorts its failures:
      a refused connection, a 429 or a 5xx produced no audio and is
      retried; a timeout, a dropped connection or an empty 200 may have
      finished and been billed on their side, so the job stops and says
      so. The same goes for audio that came back and then could not be
      uploaded: the upload is retried in place, with the bytes in memory,
      and if it still fails the job stops rather than pay for the clip
      again on a fresh attempt.

    * **An attempt that was killed mid-request is not repeated.** A
      deploy or an out-of-memory restart can kill a job while its
      ElevenLabs request is in flight, which is the whole 10 to 120
      seconds of the request, not a moment. The lifeline later frees the
      job without recording an error, so the next attempt can tell: its
      attempt count has run ahead of its errors. If nothing of ours is at
      the key by then, the killed request may still have been billed, so
      the job is cancelled with that reason instead of paying again.
      Deploys avoid the kill in the first place: Fly waits 150 seconds
      after SIGTERM (`kill_timeout` in `fly.toml`) and Oban gives running
      jobs 140 of them to finish (`shutdown_grace_period`).

  `:force` re-records an object that is already right - a deliberate
  second take - but still stops on its own upload, so even a forced job
  pays once.

  An upload counts as the job's own only when both its job id and its
  fingerprint match. Job ids are only unique within one database, and a
  copy of production's data (`sync_prod_db.sh`) once carried its job ids
  into development; a job id alone could then adopt a clip recorded from
  other words.

  ## Results

    * `{:ok, :recorded, characters}` - recorded and uploaded now
    * `{:ok, :already_recorded}` - the object was already right; nothing
      was spent
    * `{:retry, reason}` - nothing was spent; trying again may succeed
    * `{:cancel, reason}` - do not try again on its own: the failure is
      permanent, or ElevenLabs may already have charged for the clip
  """

  alias LumenViae.Audio.ElevenLabs
  alias LumenViae.Storage.S3

  require Logger

  @upload_attempts 3

  @doc """
  Records `text` in `voice` to `key`, unless the object there is already
  right. Options:

    * `:job_id` - the job doing the recording, stored on the object so a
      retry of that job recognises its own work (required)
    * `:already_right` - when an existing object counts as already right:
      `:same_fingerprint` (the default, for narrations, whose key names a
      file and not its words) or `:exists` (for keys that carry a hash of
      their text, as the spoken Rosary's do)
    * `:force` - record even if the object is already right
    * `:orphaned` - an earlier attempt of this job was killed without an
      error (see `orphaned?/1`): cancel rather than call ElevenLabs,
      unless the job's own upload is already at the key
  """
  def record(text, voice, key, opts) do
    job_id = opts |> Keyword.fetch!(:job_id) |> to_string()
    fingerprint = fingerprint(text, voice)

    case S3.audio_metadata(key) do
      {:ok, meta} ->
        cond do
          already_right?(meta, job_id, fingerprint, opts) ->
            {:ok, :already_recorded}

          opts[:orphaned] ->
            {:cancel,
             "previous attempt was killed mid-request and may be billed; " <>
               "check #{key} and run it again if it is missing"}

          true ->
            # The names already_right?/4 reads back.
            meta = [{"job", job_id}, {"fingerprint", fingerprint}]
            synthesize_and_upload(text, voice, key, meta)
        end

      {:error, reason} ->
        {:retry, "could not check #{key}: #{inspect(reason)}"}
    end
  end

  @doc """
  Whether an earlier attempt of `job` ended without an error: killed by a
  deploy or a crash and freed by the lifeline, which records none. Every
  other way an attempt ends - an error, a timeout, an exception - records
  one, and a snooze gives its attempt back.
  """
  def orphaned?(%Oban.Job{attempt: attempt, errors: errors}), do: attempt - 1 > length(errors)

  @doc """
  A short, stable digest of what a clip says and how: the text exactly as
  sent, the ElevenLabs voice, its model and its settings. Two recordings
  with the same fingerprint are the same request to ElevenLabs.
  """
  def fingerprint(text, voice) do
    settings =
      (voice.voice_settings || %{})
      |> Enum.map(fn {name, value} -> [to_string(name), value] end)
      |> Enum.sort()

    [text, voice.eleven_labs_voice_id, voice.model_id, settings]
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end

  # A job's own earlier upload, of these same words, is always right,
  # forced or not.
  defp already_right?(
         %{"job" => job_id, "fingerprint" => fingerprint},
         job_id,
         fingerprint,
         _opts
       ),
       do: true

  defp already_right?(nil, _job_id, _fingerprint, _opts), do: false

  defp already_right?(meta, _job_id, fingerprint, opts) do
    cond do
      opts[:force] -> false
      Keyword.get(opts, :already_right, :same_fingerprint) == :exists -> true
      true -> meta["fingerprint"] == fingerprint
    end
  end

  defp synthesize_and_upload(text, voice, key, meta) do
    case ElevenLabs.generate_audio(text, voice.eleven_labs_voice_id,
           model_id: voice.model_id,
           voice_settings: voice.voice_settings
         ) do
      {:ok, audio} ->
        upload(audio, key, meta, String.length(text))

      {:error, {:fatal, message}} ->
        {:cancel, message}

      {:error, {:uncertain, message}} ->
        {:cancel,
         "#{message}. ElevenLabs may have charged for this clip, so it is not retried " <>
           "automatically; check #{key} and run it again if it is missing"}

      {:error, message} ->
        {:retry, message}
    end
  end

  defp upload(audio, key, meta, characters, attempt \\ 1) do
    case S3.upload_audio(audio, key, meta: meta) do
      {:ok, ^key} ->
        {:ok, :recorded, characters}

      {:error, reason} when attempt < @upload_attempts ->
        Logger.warning("Upload of #{key} failed (attempt #{attempt}): #{inspect(reason)}")
        Process.sleep(retry_delay(attempt))
        upload(audio, key, meta, characters, attempt + 1)

      {:error, reason} ->
        {:cancel,
         "recorded but could not upload #{key} after #{@upload_attempts} attempts " <>
           "(#{inspect(reason)}); not retried, so the clip is not paid for twice"}
    end
  end

  defp retry_delay(attempt) do
    Application.get_env(:lumen_viae, :audio_retry_base_delay_ms, 2_000) * attempt
  end
end
