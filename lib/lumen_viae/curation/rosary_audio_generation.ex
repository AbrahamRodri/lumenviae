defmodule LumenViae.Curation.RosaryAudioGeneration do
  @moduledoc """
  Records the spoken Rosary (`LumenViae.Rosary.PrayerAudio`) with
  ElevenLabs, once per narration voice, and uploads each clip to its key
  in the audio bucket.

  Nothing touches the database: the catalogue is fixed content, and which
  clips exist is answered by S3 itself. Because every key carries a hash
  of what was spoken and how, a clip already at its key is already right,
  so a run skips it by default. An interrupted run is simply run again,
  and a reworded prayer is recorded without re-recording anything else.

  Used by `mix lumen_viae.generate_rosary_audio` and
  `LumenViae.Release.generate_rosary_audio/1`.

  ## Options

    * `:voices` - slugs of the voices to record (default: every configured
      voice)
    * `:kinds` - any of `:prayer`, `:announcement`, `:verse` (default: all)
    * `:force` - record and replace clips that already exist
    * `:dry_run` - say what would be recorded and how many characters it
      would cost, without calling ElevenLabs or writing to S3. Existence is
      still checked with a read-only HEAD when AWS credentials are present,
      so the count is what a real run would spend.
    * `:concurrency` - clips recorded at once (default 3, within every
      ElevenLabs plan's concurrent request limit)
    * `:progress` - a 1-arity function receiving `{:started, total}` and
      `{:item_finished, index, total, result}` events

  Returns `{:ok | :warning | :error, message}` tuples, like
  `LumenViae.Curation.AudioRegeneration`. A clip skipped because it exists
  is a warning, so the summary counts it as skipped rather than recorded.
  An unknown voice fails the whole run before anything is spent.
  """

  alias LumenViae.Audio.Pipeline
  alias LumenViae.Rosary.{PrayerAudio, Voices}
  alias LumenViae.Storage.S3

  @default_concurrency 3

  def run(opts \\ []) do
    progress = Keyword.get(opts, :progress, fn _event -> :ok end)

    case resolve_voices(Keyword.get(opts, :voices)) do
      {:ok, voices} ->
        clips = PrayerAudio.clips(Keyword.get(opts, :kinds))
        work = for voice <- voices, clip <- clips, do: {voice, clip}
        total = length(work)
        progress.({:started, total})

        work
        |> Enum.with_index(1)
        |> Task.async_stream(
          fn {{voice, clip}, index} -> {index, process(voice, clip, opts)} end,
          max_concurrency: Keyword.get(opts, :concurrency, @default_concurrency),
          timeout: :infinity,
          ordered: true
        )
        |> Enum.map(fn {:ok, {index, result}} ->
          progress.({:item_finished, index, total, result})
          result
        end)

      {:error, message} ->
        progress.({:started, 1})
        result = {:error, message}
        progress.({:item_finished, 1, 1, result})
        [result]
    end
  end

  defp resolve_voices(slugs) when slugs in [nil, []], do: {:ok, Voices.list()}

  defp resolve_voices(slugs) do
    case Enum.reject(slugs, &Voices.valid?/1) do
      [] -> {:ok, Enum.map(slugs, &Voices.get/1)}
      unknown -> {:error, "Unknown voice(s): #{Enum.join(unknown, ", ")}"}
    end
  end

  defp process(voice, clip, opts) do
    key = PrayerAudio.s3_key(voice, clip)
    text = PrayerAudio.speech_text(clip)
    label = "#{voice.slug} #{clip.kind} #{clip.name}"

    case existing(key, opts) do
      true ->
        {:warning, "#{label}: already recorded at #{key}, skipped"}

      false ->
        if opts[:dry_run] do
          {:ok, "#{label}: would record #{String.length(text)} characters to #{key}"}
        else
          record(voice, text, key, label)
        end

      {:error, reason} ->
        {:error, "#{label}: could not check #{key}: #{inspect(reason)}"}
    end
  end

  # With --force nothing is looked up; a dry run that cannot reach S3
  # assumes the clip is missing, which overstates the cost rather than
  # hiding it.
  defp existing(key, opts) do
    if opts[:force] do
      false
    else
      case {S3.audio_exists?(key), opts[:dry_run] == true} do
        {{:ok, exists?}, _dry_run} -> exists?
        {{:error, _reason}, true} -> false
        {{:error, reason}, false} -> {:error, reason}
      end
    end
  end

  # Spoken prayer text has no paragraph breaks and no pause annotations,
  # so the pipeline sends it as it is, apart from the model's own
  # escaping.
  defp record(voice, text, key, label) do
    case Pipeline.generate_and_upload(text, [], key, voice: voice) do
      {:ok, ^key} -> {:ok, "#{label}: recorded #{String.length(text)} characters to #{key}"}
      {:error, reason} -> {:error, "#{label}: #{format_reason(reason)}"}
    end
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
