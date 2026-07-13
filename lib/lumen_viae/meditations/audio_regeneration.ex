defmodule LumenViae.Meditations.AudioRegeneration do
  @moduledoc """
  Regenerates ElevenLabs narration for meditations that already have audio,
  uploading to the same S3 key so existing meditations pick up new pause
  logic (or a new voice) without re-importing and without creating
  duplicate meditations. No database rows are written; only the S3 objects
  are replaced.

  Used by `mix lumen_viae.regenerate_audio` and
  `LumenViae.Release.regenerate_audio/1`.

  ## Targets

    * `{:set, name}` - every meditation attached to the named meditation
      set, in set order
    * `{:meditation, id}` - a single meditation

  ## Options

    * `:dry_run` - list what would be regenerated; no ElevenLabs or S3 calls
    * `:progress` - a 1-arity function receiving `{:started, total}` and
      `{:item_finished, index, total, result}` events

  Results are returned as a list of `{:ok | :warning | :error, message}`
  tuples, matching `LumenViae.Meditations.CsvImport`. Meditations without
  an `audio_url` are reported as warnings and skipped: regeneration never
  invents S3 keys, it only replaces files the import already assigned.
  """

  import Ecto.Query

  alias LumenViae.Audio.{Pipeline, TtsText}
  alias LumenViae.Repo
  alias LumenViae.Rosary.{Meditation, MeditationSet, MeditationSetMeditation}

  def run(target, opts \\ [])

  def run({:set, set_name}, opts) do
    case Repo.get_by(MeditationSet, name: set_name) do
      nil ->
        fail_target("Meditation set not found: #{set_name}", opts)

      %MeditationSet{} = set ->
        set |> set_meditations() |> process(opts)
    end
  end

  def run({:meditation, id}, opts) do
    case Repo.get(Meditation, id) do
      nil ->
        fail_target("Meditation not found: id #{id}", opts)

      %Meditation{} = meditation ->
        meditation |> Repo.preload(:mystery) |> List.wrap() |> process(opts)
    end
  end

  defp fail_target(message, opts) do
    result = {:error, message}
    notify(opts, {:item_finished, 1, 1, result})
    [result]
  end

  defp set_meditations(set) do
    from(m in Meditation,
      join: msm in MeditationSetMeditation,
      on: msm.meditation_id == m.id,
      where: msm.meditation_set_id == ^set.id,
      order_by: msm.order,
      preload: [:mystery]
    )
    |> Repo.all()
  end

  defp process(meditations, opts) do
    total = length(meditations)
    notify(opts, {:started, total})

    meditations
    |> Enum.with_index(1)
    |> Enum.map(fn {meditation, index} ->
      result = process_meditation(meditation, opts)
      notify(opts, {:item_finished, index, total, result})
      result
    end)
  end

  defp process_meditation(%Meditation{audio_url: audio_url} = meditation, _opts)
       when audio_url in [nil, ""] do
    {:warning,
     "Skipped #{describe(meditation)}: it has no audio file (audio_url is not set; " <>
       "audio filenames are assigned at import)"}
  end

  defp process_meditation(meditation, opts) do
    if opts[:dry_run] do
      {:ok,
       "Would regenerate #{meditation.audio_url} for #{describe(meditation)} " <>
         "(#{pause_plan(meditation)})"}
    else
      case Pipeline.generate_and_upload(
             meditation.content,
             meditation.tts_annotations,
             meditation.audio_url
           ) do
        {:ok, s3_key} ->
          {:ok, "Regenerated #{s3_key} for #{describe(meditation)}"}

        {:error, reason} ->
          {:error,
           "Failed to regenerate #{meditation.audio_url} for #{describe(meditation)}: " <>
             format_error(reason)}
      end
    end
  end

  defp describe(%Meditation{} = meditation) do
    label =
      meditation.title || (Ecto.assoc_loaded?(meditation.mystery) && meditation.mystery.name)

    if label, do: "meditation #{meditation.id} (#{label})", else: "meditation #{meditation.id}"
  end

  defp pause_plan(meditation) do
    speech_text = TtsText.to_speech_text(meditation.content, meditation.tts_annotations || [])
    break_count = length(String.split(speech_text, "<break")) - 1
    custom_count = length(meditation.tts_annotations || [])
    "#{break_count} break tag(s), #{custom_count} custom pause(s)"
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: reason |> inspect() |> String.slice(0, 200)

  defp notify(opts, event) do
    case opts[:progress] do
      fun when is_function(fun, 1) -> fun.(event)
      _ -> :ok
    end
  end
end
