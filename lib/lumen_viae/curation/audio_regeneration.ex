defmodule LumenViae.Curation.AudioRegeneration do
  @moduledoc """
  Regenerates ElevenLabs narration for meditations that already have an
  audio filename, one recording per voice, uploading each to its voice's
  key (`voices/<slug>/<filename>`) and recording the result as a narration.
  No meditation rows are written: only S3 objects are replaced and
  narration rows upserted, so a set imported before a pause-logic, model or
  voice change can be brought up to date without re-importing and without
  duplicating anything.

  Used by `mix lumen_viae.regenerate_audio` and
  `LumenViae.Release.regenerate_audio/1`.

  ## Targets

    * `{:set, name}` - every meditation attached to the named meditation
      set, in set order
    * `{:meditation, id}` - a single meditation
    * `:all` - every active (non-archived) meditation that has an audio
      filename, in id order

  ## Options

    * `:voices` - slugs of the voices to record (default: every configured
      voice, see `LumenViae.Rosary.Voices`)
    * `:only_missing` - skip a (meditation, voice) pair that already has a
      narration on record, so an interrupted run can be resumed without
      paying ElevenLabs twice for the same recording
    * `:dry_run` - list what would be regenerated; no ElevenLabs or S3 calls
    * `:progress` - a 1-arity function receiving `{:started, total}` and
      `{:item_finished, index, total, result}` events, one item per
      (meditation, voice) pair

  Results are returned as a list of `{:ok | :warning | :error, message}`
  tuples, matching `LumenViae.Curation.CsvImport`. Meditations without
  an `audio_url` are reported as warnings and skipped: regeneration never
  invents audio filenames, it only records what the import already named.
  """

  alias LumenViae.Audio.Pipeline
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Voices

  def run(target, opts \\ [])

  def run({:set, set_name}, opts) do
    case Rosary.get_meditation_set_by_name(set_name) do
      nil ->
        fail_target("Meditation set not found: #{set_name}", opts)

      set ->
        set.id |> Rosary.list_meditations_in_set() |> process(opts)
    end
  end

  def run({:meditation, id}, opts) do
    case Rosary.get_meditation(id) do
      nil ->
        fail_target("Meditation not found: id #{id}", opts)

      meditation ->
        meditation |> List.wrap() |> process(opts)
    end
  end

  def run(:all, opts) do
    Rosary.list_meditations()
    |> Enum.reject(&Rosary.meditation_archived?/1)
    |> Enum.sort_by(& &1.id)
    |> process(opts)
  end

  defp fail_target(message, opts) do
    result = {:error, message}
    notify(opts, {:item_finished, 1, 1, result})
    [result]
  end

  defp process(meditations, opts) do
    case resolve_voices(opts[:voices]) do
      {:ok, voices} ->
        items = Enum.flat_map(meditations, &items_for(&1, voices))
        total = length(items)
        notify(opts, {:started, total})

        items
        |> Enum.with_index(1)
        |> Enum.map(fn {item, index} ->
          result = process_item(item, opts)
          notify(opts, {:item_finished, index, total, result})
          result
        end)

      {:error, unknown} ->
        fail_target(
          "Unknown voice(s): #{Enum.join(unknown, ", ")} (configured: #{Enum.join(Voices.slugs(), ", ")})",
          opts
        )
    end
  end

  # A meditation with no filename is one item, so it is reported once
  # rather than once per voice.
  defp items_for(%{audio_url: audio_url} = meditation, _voices) when audio_url in [nil, ""],
    do: [{:no_filename, meditation}]

  defp items_for(meditation, voices), do: Enum.map(voices, &{:narrate, meditation, &1})

  defp resolve_voices(nil), do: {:ok, Voices.list()}
  defp resolve_voices([]), do: {:ok, Voices.list()}

  defp resolve_voices(slugs) when is_list(slugs) do
    case Enum.reject(slugs, &Voices.valid?/1) do
      [] -> {:ok, Enum.map(slugs, &Voices.get/1)}
      unknown -> {:error, unknown}
    end
  end

  defp process_item({:no_filename, meditation}, _opts) do
    {:warning,
     "Skipped #{describe(meditation)}: it has no audio file (audio_url is not set; " <>
       "audio filenames are assigned at import)"}
  end

  defp process_item({:narrate, meditation, voice}, opts) do
    s3_key = Voices.narration_key(voice, meditation.audio_url)

    cond do
      opts[:only_missing] && recorded?(meditation, voice) ->
        {:ok, "Kept #{s3_key} for #{describe(meditation)} (already recorded)"}

      opts[:dry_run] ->
        {:ok,
         "Would regenerate #{s3_key} for #{describe(meditation)} " <>
           "(#{voice.slug} voice on #{voice.model_id}, #{pause_plan(meditation, voice)})"}

      true ->
        regenerate(meditation, voice, s3_key)
    end
  end

  defp regenerate(meditation, voice, s3_key) do
    with {:ok, s3_key} <-
           Pipeline.generate_and_upload(
             meditation.content,
             meditation.tts_annotations,
             s3_key,
             voice: voice
           ),
         {:ok, _meditation} <- Rosary.record_narration(meditation, voice.slug, s3_key) do
      {:ok, "Regenerated #{s3_key} for #{describe(meditation)} (#{voice.slug} voice)"}
    else
      {:error, reason} ->
        {:error,
         "Failed to regenerate #{s3_key} for #{describe(meditation)}: " <> format_error(reason)}
    end
  end

  defp recorded?(meditation, voice) do
    Enum.any?(Rosary.meditation_narrations(meditation), &(&1.voice.slug == voice.slug))
  end

  defp describe(meditation) do
    label =
      meditation.title || (Ecto.assoc_loaded?(meditation.mystery) && meditation.mystery.name)

    if label, do: "meditation #{meditation.id} (#{label})", else: "meditation #{meditation.id}"
  end

  defp pause_plan(meditation, voice) do
    speech_text = Pipeline.speech_text(meditation.content, meditation.tts_annotations, voice)
    pause_count = length(Regex.scan(~r/<break\b|\[(?:short |long )?pause\]/, speech_text))
    custom_count = length(meditation.tts_annotations || [])
    "#{pause_count} pause(s), #{custom_count} custom"
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
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
