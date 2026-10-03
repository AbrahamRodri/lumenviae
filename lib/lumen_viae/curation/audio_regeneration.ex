defmodule LumenViae.Curation.AudioRegeneration do
  @moduledoc """
  Regenerates ElevenLabs narration for meditations that already have an
  audio filename, one recording per voice, by enqueueing one
  `LumenViae.Curation.Jobs.NarrateMeditation` job per (meditation, voice).
  Each job uploads to its voice's key (`voices/<slug>/<filename>`) and
  records the result as a narration. No meditation rows are written: only
  S3 objects are replaced and narration rows upserted, so a set imported
  before a pause-logic, model or voice change can be brought up to date
  without re-importing and without duplicating anything.

  A job records only when the object at the key is not already what it
  would record: every upload carries a fingerprint of the text, voice,
  model and settings it was made from (`LumenViae.Audio.Recording`). So a
  pause-logic, model or voice change is recorded, a recording made before
  fingerprints existed is recorded once more, and running the same
  regeneration twice pays for nothing the second time. `:force` records
  anyway, for a deliberate second take.

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
    * `:force` - record even when the object already matches
    * `:dry_run` - list what would be regenerated; nothing is enqueued and
      no ElevenLabs or S3 calls are made
    * `:batch` - the batch the jobs are enqueued under
      (`AudioJobs.new_batch/0` by default); pass one to wait on it
    * `:progress` - a 1-arity function receiving `{:started, total}` and
      `{:item_finished, index, total, result}` events, one item per
      (meditation, voice) pair
    * `:actor` - the admin the regeneration runs as, when the console
      starts it
    * `:authorize?` - `false` only from an operator's shell (mix tasks,
      `LumenViae.Release`), which already holds the database

  Results are returned as a list of `{:ok | :warning | :error, message}`
  tuples, matching `LumenViae.Curation.CsvImport`. An `:ok` is a recording
  queued (or, in a dry run, one that would be); what the job then did is
  in its batch (`AudioJobs.progress/1`). Meditations without
  an `audio_url` are reported as warnings and skipped: regeneration never
  invents audio filenames, it only records what the import already named.
  """

  alias LumenViae.AshOpts
  alias LumenViae.Audio.Pipeline
  alias LumenViae.Curation.AudioJobs
  alias LumenViae.Curation.Jobs.NarrateMeditation
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Voices

  def run(target, opts \\ [])

  def run({:set, set_name}, opts) do
    case Rosary.get_meditation_set_by_name(set_name, nil, AshOpts.take(opts)) do
      nil ->
        fail_target("Meditation set not found: #{set_name}", opts)

      set ->
        set.id |> Rosary.list_meditations_in_set(AshOpts.take(opts)) |> process(opts)
    end
  end

  def run({:meditation, id}, opts) do
    case Rosary.get_meditation(id, AshOpts.take(opts)) do
      {:ok, meditation} ->
        meditation |> List.wrap() |> process(opts)

      {:error, _not_found} ->
        fail_target("Meditation not found: id #{id}", opts)
    end
  end

  def run(:all, opts) do
    Rosary.list_meditations!(AshOpts.take(opts))
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
    opts = AudioJobs.with_batch(opts)

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
      opts[:only_missing] && recorded?(meditation, voice, opts) ->
        {:ok, "Kept #{s3_key} for #{describe(meditation)} (already recorded)"}

      opts[:dry_run] ->
        {:ok,
         "Would regenerate #{s3_key} for #{describe(meditation)} " <>
           "(#{voice.slug} voice on #{voice.model_id}, #{pause_plan(meditation, voice)})"}

      true ->
        enqueue(meditation, voice, s3_key, opts)
    end
  end

  defp enqueue(meditation, voice, s3_key, opts) do
    case meditation
         |> NarrateMeditation.new_for(voice, meditation.audio_url,
           force: opts[:force] == true,
           keep_existing: opts[:only_missing] == true
         )
         |> AudioJobs.enqueue(opts[:batch]) do
      {:ok, :queued} ->
        {:ok, "Queued #{s3_key} for #{describe(meditation)} (#{voice.slug} voice)"}

      {:ok, :already_queued} ->
        {:ok, "Already queued #{s3_key} for #{describe(meditation)} (#{voice.slug} voice)"}

      {:error, reason} ->
        {:error,
         "Could not queue #{s3_key} for #{describe(meditation)}: " <> format_error(reason)}
    end
  end

  defp recorded?(meditation, voice, opts) do
    meditation
    |> Rosary.meditation_narrations(AshOpts.take(opts))
    |> Enum.any?(&(&1.voice.slug == voice.slug))
  end

  defp describe(meditation) do
    label = meditation.title || mystery_name(meditation.mystery)

    if label, do: "meditation #{meditation.id} (#{label})", else: "meditation #{meditation.id}"
  end

  # Not Ecto.assoc_loaded?/1: it answers true for anything that is not
  # Ecto's own not-loaded marker, Ash's included, and the label would then
  # crash reading a name off a relationship that was never loaded.
  defp mystery_name(%{name: name}), do: name
  defp mystery_name(_not_loaded_or_nil), do: nil

  defp pause_plan(meditation, voice) do
    speech_text = Pipeline.speech_text(meditation.content, meditation.tts_annotations, voice)
    pause_count = length(Regex.scan(~r/<break\b|\[(?:short |long )?pause\]/, speech_text))
    custom_count = length(meditation.tts_annotations || [])
    "#{pause_count} pause(s), #{custom_count} custom"
  end

  defp format_error(%Ash.Error.Invalid{} = error), do: Rosary.error_summary(error)

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: reason |> inspect() |> String.slice(0, 200)

  defp notify(opts, event) do
    case opts[:progress] do
      fun when is_function(fun, 1) -> fun.(event)
      _ -> :ok
    end
  end
end
