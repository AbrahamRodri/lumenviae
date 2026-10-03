defmodule LumenViae.Curation.CsvImport do
  @moduledoc """
  Shared CSV import engine for meditations and meditation sets.

  Used by the admin LiveView upload flow, the `mix lumen_viae.import` task,
  and `LumenViae.Release.import_csv/2`, so batch imports behave identically
  whether they come through the browser or the command line.

  ## CSV format

  A UTF-8 BOM is tolerated, fully blank rows are skipped, and headers are
  validated strictly: the required columns must be present and unknown
  columns are rejected (they are usually typos that would otherwise be
  silently ignored).

  Required columns:

    * `mystery_name` - must exactly match an existing mystery name
    * `content` - the meditation text. It may carry inline `{pause:N}`
      markers (N in seconds, decimals allowed, capped at 3) to tune the
      narration pause at that spot; markers are stripped before the content
      is stored and their positions are persisted as TTS annotations so only
      the audio generation sees them (see `LumenViae.Audio.TtsText`). A
      marker on its own line between two paragraphs replaces that paragraph
      break's default pause. Literal `<break` tags are rejected.

  Optional meditation columns:

    * `title` - meditation title
    * `author` - meditation author
    * `source` - meditation source
    * `audio_filename` - when present, narration is recorded with
      ElevenLabs once per configured voice (see `LumenViae.Rosary.Voices`)
      and uploaded to S3 at `voices/<slug>/<audio_filename>`. The import
      writes the row and enqueues one `LumenViae.Curation.Jobs.NarrateMeditation`
      job per voice; the jobs record in the background, set the
      meditation's `audio_url` with the first recording that lands, and
      can be followed in the batch (see `:batch`). A voice whose job fails
      leaves the meditation without that narration, and `mix
      lumen_viae.regenerate_audio --only-missing` fills the gap later. The
      same filename may not appear on more than one row.

  Optional meditation set columns:

    * `set_name` - find-or-create a meditation set with this name and attach
      the row's meditation to it. Sets are looked up by name and
      `set_category` together, because a name repeats across categories
      ("St. Alphonsus Liguori" is four sets); a row that names a set
      without its category is an error when more than one set has that name
    * `set_category` - required when the set does not exist yet; one of
      joyful, sorrowful, glorious, luminous, seven_sorrows
    * `set_description` - set description (used on create only)
    * `set_author` - the set's own byline, e.g. "Bl. Anne Catherine
      Emmerich" (create only). Leave it out and the byline is derived from
      the meditations, but only when every one of them agrees.
    * `set_source` - the work the set is drawn from (create only)
    * `set_labels` - pipe-separated labels from the managed vocabulary
      (see `LumenViae.Rosary.Labels`); order matters, the first label is the
      set's primary group (create only)
    * `order` - explicit position of the meditation within the set; when
      omitted, rows are appended after the set's current highest order

  ## Options

    * `:skip_audio` - ignore audio_filename columns; no ElevenLabs/S3 calls
    * `:voices` - slugs of the voices to record (default: every configured
      voice)
    * `:dry_run` - validate rows without writing to the database or
      enqueueing anything
    * `:batch` - the batch the narration jobs are enqueued under
      (`LumenViae.Curation.AudioJobs.new_batch/0` by default); pass one to
      follow the recordings or wait for them
    * `:progress` - a 1-arity function receiving progress events (see below)
    * `:actor` - the admin the import runs as; the console passes the
      signed-in admin
    * `:authorize?` - `false` only from an operator's shell (mix tasks,
      `LumenViae.Release`), which already holds the database

  `preview_string/2` takes `:actor` and `:authorize?` the same way.

  ## Progress events

  When a `:progress` fun is given, it is called with:

    * `{:started, total}` - once, before the first row
    * `{:row_started, index, total, description}` - a row began processing
    * `{:row_audio, index, total, key}` - a narration job was enqueued for
      one voice; `key` is that voice's S3 key
    * `{:row_finished, index, total, {:ok | :warning | :error, message}}` -
      row result

  Results are returned as a list of `{:ok, message}` / `{:warning, message}`
  / `{:error, message}` tuples, in row order. A `:warning` means the
  meditation row was written but something non-fatal went wrong (a
  narration could not be enqueued, or the meditation could not be attached
  to its set). The recordings themselves finish after the import returns;
  their outcomes are the batch's, not the rows'.
  """

  alias LumenViae.AshOpts
  alias LumenViae.Audio.TtsText
  alias LumenViae.Curation.AudioJobs
  alias LumenViae.Curation.Jobs.NarrateMeditation
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Voices

  require Logger

  NimbleCSV.define(LumenViae.Curation.CsvImport.Parser, separator: ",", escape: "\"")

  alias LumenViae.Curation.CsvImport.Parser

  @required_columns ~w(mystery_name content)
  @known_columns ~w(mystery_name content title author source audio_filename
                    set_name set_category set_description set_author set_source
                    set_labels order)

  ## Importing

  @doc """
  Imports meditations from a CSV file on disk.
  """
  def import_file(path, opts \\ []) do
    case File.read(path) do
      {:ok, content} -> import_string(content, opts)
      {:error, reason} -> [{:error, "Failed to read file: #{inspect(reason)}"}]
    end
  end

  @doc """
  Imports meditations from CSV content in memory.
  """
  def import_string(content, opts \\ []) do
    case parse(content) do
      {:error, message} ->
        [{:error, message}]

      {:ok, headers, rows} ->
        process_rows(headers, rows, AudioJobs.with_batch(opts))
    end
  end

  ## Preview (validation without writes)

  @doc """
  Parses and validates CSV content without writing anything, returning a
  structured preview for UI display.

  Returns `{:ok, preview}` where preview is a map with:

    * `:rows` - a list of row maps with `:index`, `:mystery_name`,
      `:mystery_ok`, `:title`, `:author`, `:content_chars`, `:paragraphs`,
      `:content_excerpt`, `:audio_filename`, `:set_name`, `:set_status`
      (`:existing` | `:new` | `nil`), `:set_labels`, `:order`, `:errors`,
      `:warnings`
    * `:total` - row count
    * `:valid_count` / `:error_count` - rows without/with errors
    * `:audio_count` - rows that will generate audio
    * `:new_sets` / `:existing_sets` - distinct set names by status

  Returns `{:error, message}` when the file itself is unusable.
  """
  def preview_string(content, opts \\ []) do
    case parse(content) do
      {:error, message} ->
        {:error, message}

      {:ok, headers, rows} ->
        mysteries = Rosary.list_mysteries!(AshOpts.take(opts)) |> Enum.group_by(& &1.name)

        indexed_rows =
          rows
          |> Enum.with_index(1)
          |> Enum.map(fn {row, index} -> {index, row_to_map(headers, row)} end)

        row_maps = Enum.map(indexed_rows, fn {_index, {row_map, _errors}} -> row_map end)
        set_statuses = preview_set_statuses(row_maps, opts)
        duplicate_audio = duplicate_audio_filenames(row_maps)
        existing_audio = existing_audio_keys(row_maps, opts)

        row_infos =
          Enum.map(indexed_rows, fn {index, {row_map, structure_errors}} ->
            preview_row(
              index,
              row_map,
              mysteries,
              set_statuses,
              structure_errors,
              duplicate_audio,
              existing_audio
            )
          end)

        {:ok,
         %{
           rows: row_infos,
           total: length(row_infos),
           valid_count: Enum.count(row_infos, &(&1.errors == [])),
           error_count: Enum.count(row_infos, &(&1.errors != [])),
           audio_count: Enum.count(row_infos, & &1.audio_filename),
           new_sets: for({name, {:new, _}} <- set_statuses, do: name) |> Enum.sort(),
           existing_sets: for({name, {:existing, _}} <- set_statuses, do: name) |> Enum.sort()
         }}
    end
  end

  defp preview_set_statuses(row_maps, opts) do
    row_maps
    |> Enum.filter(&Map.get(&1, "set_name"))
    |> Enum.uniq_by(&Map.get(&1, "set_name"))
    |> Map.new(fn row_map ->
      set_name = Map.get(row_map, "set_name")

      status =
        case lookup_set(row_map, opts) do
          {:ok, nil} -> {:new, new_set_errors(row_map, opts)}
          {:ok, _set} -> {:existing, []}
          {:error, message} -> {:new, [message]}
        end

      {set_name, status}
    end)
  end

  defp new_set_errors(row_map, opts) do
    changeset = Rosary.changeset_to_create_meditation_set(set_attrs(row_map), AshOpts.take(opts))

    if changeset.valid?, do: [], else: ["set: #{changeset_errors(changeset)}"]
  end

  defp preview_row(
         index,
         row_map,
         mysteries,
         set_statuses,
         structure_errors,
         duplicate_audio,
         existing_audio
       ) do
    mystery_name = Map.get(row_map, "mystery_name")
    mystery_ok = mystery_name != nil and get_in(mysteries, [mystery_name, Access.at(0)]) != nil
    {content, tts_annotations, marker_errors} = preview_content(Map.get(row_map, "content"))
    audio_filename = Map.get(row_map, "audio_filename")
    set_name = Map.get(row_map, "set_name")

    {set_status, set_errors} =
      case set_statuses[set_name] do
        nil -> {nil, []}
        {status, errors} -> {status, errors}
      end

    errors =
      structure_errors ++
        mystery_errors(mystery_name, mystery_ok) ++
        content_errors(content) ++
        marker_errors ++
        duplicate_audio_errors(audio_filename, duplicate_audio) ++
        set_errors

    warnings =
      content_warnings(content) ++ audio_overwrite_warnings(audio_filename, existing_audio)

    %{
      index: index,
      mystery_name: mystery_name,
      mystery_ok: mystery_ok,
      title: Map.get(row_map, "title"),
      author: Map.get(row_map, "author"),
      content_chars: (content && String.length(content)) || 0,
      paragraphs: (content && String.split(content, "\n\n") |> length()) || 0,
      content_excerpt: content_excerpt(content),
      pause_count: length(tts_annotations),
      audio_filename: audio_filename,
      set_name: set_name,
      set_status: set_status,
      set_labels: parse_labels(Map.get(row_map, "set_labels")),
      order: Map.get(row_map, "order"),
      errors: errors,
      warnings: warnings
    }
  end

  defp mystery_errors(nil, _mystery_ok), do: ["missing mystery_name"]
  defp mystery_errors(mystery_name, false), do: ["mystery not found: #{mystery_name}"]
  defp mystery_errors(_mystery_name, true), do: []

  # Preview counterpart of extract_content/2: cleans the content the same
  # way the import will, surfacing marker problems as row errors. Unusable
  # content is kept as-is so the excerpt still shows what is wrong.
  defp preview_content(nil), do: {nil, [], []}

  defp preview_content(raw_content) do
    case TtsText.extract_pauses(raw_content) do
      {:ok, clean_content, annotations} -> {clean_content, annotations, []}
      {:error, message} -> {raw_content, [], [message]}
    end
  end

  defp content_errors(nil), do: ["missing content"]
  defp content_errors(""), do: ["missing content"]
  defp content_errors(_content), do: []

  defp content_warnings(nil), do: []

  defp content_warnings(content) do
    paragraph_warnings =
      if String.contains?(content, "\n\n"),
        do: [],
        else: ["no paragraph breaks (see curation guide)"]

    length_warnings =
      if String.length(content) > 2500,
        do: ["long content: audio will be lengthy and costly"],
        else: []

    paragraph_warnings ++ length_warnings
  end

  defp duplicate_audio_errors(nil, _duplicate_audio), do: []

  defp duplicate_audio_errors(audio_filename, duplicate_audio) do
    if MapSet.member?(duplicate_audio, audio_filename) do
      ["duplicate audio_filename '#{audio_filename}' also used by another row"]
    else
      []
    end
  end

  defp audio_overwrite_warnings(nil, _existing_audio), do: []

  defp audio_overwrite_warnings(audio_filename, existing_audio) do
    if MapSet.member?(existing_audio, audio_filename) do
      [
        "audio_filename already belongs to an existing meditation; importing will overwrite its audio in S3"
      ]
    else
      []
    end
  end

  defp content_excerpt(nil), do: nil

  defp content_excerpt(content) do
    flat = content |> String.replace(~r/\s+/, " ") |> String.trim()
    if String.length(flat) > 160, do: String.slice(flat, 0, 160) <> "...", else: flat
  end

  ## Shared parsing

  defp parse(content) do
    # Spreadsheet exports often prepend a UTF-8 BOM, which would otherwise
    # glue itself to the first header name and break header matching.
    content = String.replace_prefix(content, "\uFEFF", "")

    case Parser.parse_string(content, skip_headers: false) do
      [] ->
        {:error, "CSV file is empty"}

      [headers | rows] ->
        headers = Enum.map(headers, &(&1 |> String.trim() |> String.downcase()))
        rows = reject_blank_rows(rows)

        with :ok <- validate_headers(headers) do
          if rows == [] do
            {:error, "CSV file has no data rows"}
          else
            {:ok, headers, rows}
          end
        end
    end
  end

  defp reject_blank_rows(rows) do
    Enum.reject(rows, fn row -> Enum.all?(row, &(String.trim(&1) == "")) end)
  end

  defp validate_headers(headers) do
    missing = @required_columns -- headers
    unknown = headers |> Enum.uniq() |> Kernel.--(@known_columns)
    duplicates = headers |> Kernel.--(Enum.uniq(headers)) |> Enum.uniq()

    cond do
      missing != [] ->
        {:error, "CSV is missing required column(s): #{Enum.join(missing, ", ")}"}

      unknown != [] ->
        {:error,
         "CSV has unknown column(s): #{format_column_names(unknown)}. " <>
           "Allowed columns: #{Enum.join(@known_columns, ", ")}"}

      duplicates != [] ->
        {:error, "CSV has duplicate column(s): #{format_column_names(duplicates)}"}

      true ->
        :ok
    end
  end

  defp format_column_names(names) do
    names
    |> Enum.map(fn
      "" -> "(empty header)"
      name -> name
    end)
    |> Enum.join(", ")
  end

  # Zips one raw CSV row against the headers. A field-count mismatch means
  # the row would be silently truncated or padded (usually an unescaped
  # comma), so it is surfaced as a row error instead.
  defp row_to_map(headers, row) do
    row_map = headers |> Enum.zip(row) |> Map.new() |> normalize_row()

    if length(row) == length(headers) do
      {row_map, []}
    else
      {row_map,
       [
         "row has #{length(row)} fields but the header has #{length(headers)} " <>
           "(check for unescaped commas or missing cells)"
       ]}
    end
  end

  defp duplicate_audio_filenames(row_maps) do
    row_maps
    |> Enum.map(&Map.get(&1, "audio_filename"))
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_filename, count} -> count > 1 end)
    |> MapSet.new(fn {filename, _count} -> filename end)
  end

  defp existing_audio_keys(row_maps, opts) do
    filenames =
      row_maps
      |> Enum.map(&Map.get(&1, "audio_filename"))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    filenames |> Rosary.list_taken_audio_urls(AshOpts.take(opts)) |> MapSet.new()
  end

  ## Row processing

  defp process_rows(headers, rows, opts) do
    # An unknown voice is a typo on a command line: refuse it before any
    # row is written, not after the first.
    unless opts[:dry_run] || opts[:skip_audio], do: import_voices(opts)

    mysteries = Rosary.list_mysteries!(AshOpts.take(opts)) |> Enum.group_by(& &1.name)
    total = length(rows)
    notify(opts, {:started, total})

    indexed_rows =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, index} ->
        {row_map, structure_errors} = row_to_map(headers, row)
        {index, row_map, structure_errors}
      end)

    duplicate_audio =
      indexed_rows
      |> Enum.map(fn {_index, row_map, _errors} -> row_map end)
      |> duplicate_audio_filenames()

    {results, _sets_cache} =
      Enum.map_reduce(indexed_rows, %{}, fn {index, row_map, structure_errors}, sets_cache ->
        description = Map.get(row_map, "mystery_name") || "row #{index}"
        notify(opts, {:row_started, index, total, description})

        audio_filename = Map.get(row_map, "audio_filename")
        errors = structure_errors ++ duplicate_audio_errors(audio_filename, duplicate_audio)

        {result, sets_cache} =
          case errors do
            [] -> process_row(row_map, mysteries, sets_cache, {index, total}, opts)
            errors -> {{:error, "Row #{index}: #{Enum.join(errors, "; ")}"}, sets_cache}
          end

        notify(opts, {:row_finished, index, total, result})
        {result, sets_cache}
      end)

    results
  end

  defp normalize_row(row_map) do
    Map.new(row_map, fn {key, value} ->
      value = value |> to_string() |> String.trim()
      {key, if(value == "", do: nil, else: value)}
    end)
  end

  defp process_row(row_map, mysteries, sets_cache, {index, total}, opts) do
    mystery_name = Map.get(row_map, "mystery_name")

    with {:ok, mystery} <- fetch_mystery(mysteries, mystery_name),
         {:ok, content, tts_annotations} <- extract_content(row_map, mystery_name),
         {:ok, set, sets_cache} <- resolve_set(row_map, sets_cache, opts) do
      attrs = %{
        "mystery_id" => mystery.id,
        "title" => Map.get(row_map, "title"),
        "content" => content,
        "tts_annotations" => tts_annotations,
        "author" => Map.get(row_map, "author"),
        "source" => Map.get(row_map, "source")
      }

      if opts[:dry_run] do
        {dry_run_result(attrs, row_map, mystery, set, opts), sets_cache}
      else
        {create_and_attach(attrs, row_map, mystery, set, {index, total}, opts), sets_cache}
      end
    else
      {:error, message} -> {{:error, message}, sets_cache}
    end
  end

  # Strips {pause:N} markers before anything is validated or stored; only
  # audio generation ever sees pause information again, via the persisted
  # annotations (see LumenViae.Audio.TtsText).
  defp extract_content(row_map, mystery_name) do
    case Map.get(row_map, "content") do
      nil ->
        {:ok, nil, []}

      raw_content ->
        case TtsText.extract_pauses(raw_content) do
          {:ok, clean_content, annotations} ->
            {:ok, clean_content, annotations}

          {:error, message} ->
            {:error, "Invalid content for '#{mystery_name}': #{message}"}
        end
    end
  end

  defp fetch_mystery(_mysteries, nil), do: {:error, "Row is missing mystery_name"}

  defp fetch_mystery(mysteries, mystery_name) do
    case get_in(mysteries, [mystery_name, Access.at(0)]) do
      nil ->
        {:error,
         "Mystery not found: #{mystery_name}. Make sure the mystery name exactly matches an existing mystery."}

      mystery ->
        {:ok, mystery}
    end
  end

  # Set resolution: rows without set columns behave exactly like the legacy
  # import and are not attached to any set. Sets are found by name and
  # created on first use, then cached for the rest of the file so every row
  # attaches to the same record.
  defp resolve_set(row_map, sets_cache, opts) do
    case Map.get(row_map, "set_name") do
      nil ->
        {:ok, nil, sets_cache}

      set_name ->
        case Map.fetch(sets_cache, set_name) do
          {:ok, set} ->
            {:ok, set, sets_cache}

          :error ->
            with {:ok, set} <- find_or_create_set(set_name, row_map, opts) do
              {:ok, set, Map.put(sets_cache, set_name, set)}
            end
        end
    end
  end

  defp find_or_create_set(set_name, row_map, opts) do
    case lookup_set(row_map, opts) do
      {:ok, nil} ->
        attrs = set_attrs(row_map)

        if opts[:dry_run] do
          validate_set_attrs(set_name, attrs, opts)
        else
          case Rosary.create_meditation_set(attrs, AshOpts.take(opts)) do
            {:ok, set} -> {:ok, set}
            {:error, changeset} -> {:error, set_error(set_name, changeset)}
          end
        end

      {:ok, set} ->
        {:ok, set}

      {:error, message} ->
        {:error, message}
    end
  end

  # The set a row names, by name and category together. A row without a
  # category can only mean a name that exists once; when the same name
  # stands in several categories the row has to say which, or the
  # meditation would be appended to the wrong Rosary.
  defp lookup_set(row_map, opts) do
    set_name = Map.get(row_map, "set_name")

    case Map.get(row_map, "set_category") do
      nil ->
        case Rosary.get_meditation_set_by_name(set_name, nil, AshOpts.take(opts)) do
          nil ->
            if Rosary.count_meditation_sets_by_name(set_name, AshOpts.take(opts)) > 1 do
              {:error,
               "set '#{set_name}' exists in more than one category; add a set_category column " <>
                 "to say which one"}
            else
              {:ok, nil}
            end

          set ->
            {:ok, set}
        end

      category ->
        {:ok, Rosary.get_meditation_set_by_name(set_name, category, AshOpts.take(opts))}
    end
  end

  defp set_attrs(row_map) do
    %{
      "name" => Map.get(row_map, "set_name"),
      "category" => Map.get(row_map, "set_category"),
      "description" => Map.get(row_map, "set_description"),
      "author" => Map.get(row_map, "set_author"),
      "source" => Map.get(row_map, "set_source"),
      "labels" => parse_labels(Map.get(row_map, "set_labels"))
    }
  end

  # A dry run never writes, so the "set" carried through the rest of the row
  # is just its name - there is no record and no id to attach to.
  defp validate_set_attrs(set_name, attrs, opts) do
    changeset = Rosary.changeset_to_create_meditation_set(attrs, AshOpts.take(opts))

    if changeset.valid? do
      {:ok, %{id: nil, name: set_name}}
    else
      {:error, set_error(set_name, changeset)}
    end
  end

  defp set_error(set_name, changeset) do
    "Failed to create meditation set '#{set_name}': #{changeset_errors(changeset)}"
  end

  defp parse_labels(nil), do: []

  defp parse_labels(labels) do
    labels
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp dry_run_result(attrs, row_map, mystery, set, opts) do
    changeset = Rosary.changeset_to_create_meditation(attrs, AshOpts.take(opts))

    if changeset.valid? do
      set_info = if set, do: " -> set '#{set.name}'#{order_info(row_map)}", else: ""
      audio_info = dry_run_audio_info(row_map, opts)
      {:ok, "Would create meditation for #{mystery.name}#{set_info}#{audio_info}"}
    else
      {:error, "Invalid meditation for '#{mystery.name}': #{changeset_errors(changeset)}"}
    end
  end

  defp dry_run_audio_info(row_map, opts) do
    cond do
      is_nil(Map.get(row_map, "audio_filename")) -> ""
      opts[:skip_audio] -> " (audio skipped)"
      true -> " (audio)"
    end
  end

  defp order_info(row_map) do
    case Map.get(row_map, "order") do
      nil -> ""
      order -> " at order #{order}"
    end
  end

  defp create_and_attach(attrs, row_map, mystery, set, position, opts) do
    case Rosary.create_meditation(attrs, AshOpts.take(opts)) do
      {:ok, meditation} ->
        narration = queue_narration(meditation, row_map, position, opts)

        case attach_to_set(set, meditation, row_map, opts) do
          :ok ->
            created_result(attrs, mystery, set, narration)

          {:error, message} ->
            {:warning,
             "Created meditation for #{mystery.name} but failed to attach to set '#{set.name}': #{message}"}
        end

      {:error, changeset} ->
        {:error,
         "Failed to create meditation for '#{mystery.name}': #{changeset_errors(changeset)}"}
    end
  end

  # One job per voice. The meditation is written without an audio_url; the
  # first recording to land sets it, so it never claims audio that is not
  # there yet. Returns {queued voice slugs, failure messages}.
  defp queue_narration(meditation, row_map, {index, total}, opts) do
    audio_filename = Map.get(row_map, "audio_filename")

    if opts[:skip_audio] || is_nil(audio_filename) || is_nil(meditation.content) do
      {[], []}
    else
      opts
      |> import_voices()
      |> Enum.reduce({[], []}, fn voice, {queued, failures} ->
        notify(opts, {:row_audio, index, total, Voices.narration_key(voice, audio_filename)})

        case meditation
             |> NarrateMeditation.new_for(voice, audio_filename)
             |> AudioJobs.enqueue(opts[:batch]) do
          {:ok, _queued_or_already} ->
            {queued ++ [voice.slug], failures}

          {:error, reason} ->
            Logger.error(
              "Could not queue #{voice.slug} narration of meditation #{meditation.id}: #{inspect(reason)}"
            )

            {queued,
             failures ++ ["#{voice.slug}: could not queue (#{format_audio_error(reason)})"]}
        end
      end)
    end
  end

  defp created_result(attrs, mystery, set, {queued, failures}) do
    title_info = if attrs["title"], do: " - #{attrs["title"]}", else: ""
    audio_info = if queued == [], do: "", else: " (narration queued: #{Enum.join(queued, ", ")})"
    set_info = if set, do: " [set: #{set.name}]", else: ""
    base = "Created meditation for #{mystery.name}#{title_info}#{audio_info}#{set_info}"

    case failures do
      [] ->
        {:ok, base}

      failures ->
        {:warning, "#{base} but narration could not be queued for #{Enum.join(failures, "; ")}"}
    end
  end

  defp attach_to_set(nil, _meditation, _row_map, _opts), do: :ok

  defp attach_to_set(set, meditation, row_map, opts) do
    order = explicit_order(row_map) || Rosary.next_order_in_set(set.id, AshOpts.take(opts))

    case Rosary.add_meditation_to_set(set.id, meditation.id, order, AshOpts.take(opts)) do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset_errors(changeset)}
    end
  end

  defp explicit_order(row_map) do
    case Map.get(row_map, "order") do
      nil ->
        nil

      value ->
        case Integer.parse(value) do
          {order, ""} -> order
          _ -> nil
        end
    end
  end

  # An unknown slug in :voices is a typo in a command line, and the import
  # should not quietly record nothing for it.
  defp import_voices(opts) do
    case opts[:voices] do
      nil -> Voices.list()
      [] -> Voices.list()
      slugs -> Enum.map(slugs, &(Voices.get(&1) || raise(ArgumentError, "unknown voice: #{&1}")))
    end
  end

  defp format_audio_error(reason) when is_binary(reason), do: reason
  defp format_audio_error(reason), do: reason |> inspect() |> String.slice(0, 200)

  defp notify(opts, event) do
    case opts[:progress] do
      fun when is_function(fun, 1) -> fun.(event)
      _ -> :ok
    end
  end

  defp changeset_errors(error), do: Rosary.error_summary(error)
end
