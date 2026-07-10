defmodule LumenViae.Meditations.CsvImport do
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
    * `content` - the meditation text

  Optional meditation columns:

    * `title` - meditation title
    * `author` - meditation author
    * `source` - meditation source
    * `audio_filename` - when present, audio is generated with ElevenLabs and
      uploaded to S3 under this key; the meditation is still created if audio
      generation fails (reported as a `:warning` result). The same filename
      may not appear on more than one row.

  Optional meditation set columns:

    * `set_name` - find-or-create a meditation set with this name and attach
      the row's meditation to it
    * `set_category` - required when the set does not exist yet; one of
      joyful, sorrowful, glorious, seven_sorrows
    * `set_description` - set description (used on create only)
    * `set_labels` - pipe-separated labels from the managed vocabulary
      (see `LumenViae.Rosary.Labels`); order matters, the first label is the
      set's primary group (create only)
    * `order` - explicit position of the meditation within the set; when
      omitted, rows are appended after the set's current highest order

  ## Options

    * `:skip_audio` - ignore audio_filename columns; no ElevenLabs/S3 calls
    * `:dry_run` - validate rows without writing to the database or
      generating audio
    * `:progress` - a 1-arity function receiving progress events (see below)

  ## Progress events

  When a `:progress` fun is given, it is called with:

    * `{:started, total}` - once, before the first row
    * `{:row_started, index, total, description}` - a row began processing
    * `{:row_audio, index, total, filename}` - audio generation began
    * `{:row_audio_retry, index, total, filename, attempt, max}` - a
      transient ElevenLabs/S3 failure is being retried
    * `{:row_finished, index, total, {:ok | :warning | :error, message}}` -
      row result

  Results are returned as a list of `{:ok, message}` / `{:warning, message}`
  / `{:error, message}` tuples, in row order. A `:warning` means the
  meditation row was written but something non-fatal went wrong (audio
  generation failed, or the meditation could not be attached to its set).
  """

  import Ecto.Query

  alias LumenViae.Audio.ElevenLabs
  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.{Meditation, MeditationSet, MeditationSetMeditation}
  alias LumenViae.Storage.S3

  require Logger

  NimbleCSV.define(LumenViae.Meditations.CsvImport.Parser, separator: ",", escape: "\"")

  alias LumenViae.Meditations.CsvImport.Parser

  @required_columns ~w(mystery_name content)
  @known_columns ~w(mystery_name content title author source audio_filename
                    set_name set_category set_description set_labels order)

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
        process_rows(headers, rows, opts)
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
  def preview_string(content) do
    case parse(content) do
      {:error, message} ->
        {:error, message}

      {:ok, headers, rows} ->
        mysteries = Rosary.list_mysteries() |> Enum.group_by(& &1.name)

        indexed_rows =
          rows
          |> Enum.with_index(1)
          |> Enum.map(fn {row, index} -> {index, row_to_map(headers, row)} end)

        row_maps = Enum.map(indexed_rows, fn {_index, {row_map, _errors}} -> row_map end)
        set_statuses = preview_set_statuses(row_maps)
        duplicate_audio = duplicate_audio_filenames(row_maps)
        existing_audio = existing_audio_keys(row_maps)

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

  @doc """
  Same as `preview_string/1` but reads from a file path.
  """
  def preview_file(path) do
    case File.read(path) do
      {:ok, content} -> preview_string(content)
      {:error, reason} -> {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  defp preview_set_statuses(row_maps) do
    row_maps
    |> Enum.filter(&Map.get(&1, "set_name"))
    |> Enum.uniq_by(&Map.get(&1, "set_name"))
    |> Map.new(fn row_map ->
      set_name = Map.get(row_map, "set_name")

      status =
        case Repo.get_by(MeditationSet, name: set_name) do
          %MeditationSet{} -> {:existing, []}
          nil -> {:new, new_set_errors(row_map)}
        end

      {set_name, status}
    end)
  end

  defp new_set_errors(row_map) do
    changeset =
      MeditationSet.changeset(%MeditationSet{}, %{
        "name" => Map.get(row_map, "set_name"),
        "category" => Map.get(row_map, "set_category"),
        "description" => Map.get(row_map, "set_description"),
        "labels" => parse_labels(Map.get(row_map, "set_labels"))
      })

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
    content = Map.get(row_map, "content")
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

  defp content_errors(nil), do: ["missing content"]
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

  defp existing_audio_keys(row_maps) do
    filenames =
      row_maps
      |> Enum.map(&Map.get(&1, "audio_filename"))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if filenames == [] do
      MapSet.new()
    else
      from(m in Meditation, where: m.audio_url in ^filenames, select: m.audio_url)
      |> Repo.all()
      |> MapSet.new()
    end
  end

  ## Row processing

  defp process_rows(headers, rows, opts) do
    mysteries = Rosary.list_mysteries() |> Enum.group_by(& &1.name)
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
         {:ok, set, sets_cache} <- resolve_set(row_map, sets_cache, opts) do
      attrs = %{
        "mystery_id" => mystery.id,
        "title" => Map.get(row_map, "title"),
        "content" => Map.get(row_map, "content"),
        "author" => Map.get(row_map, "author"),
        "source" => Map.get(row_map, "source")
      }

      if opts[:dry_run] do
        {dry_run_result(attrs, row_map, mystery, set, opts), sets_cache}
      else
        {attrs, audio_error} = maybe_generate_audio(attrs, row_map, {index, total}, opts)
        {create_and_attach(attrs, row_map, mystery, set, audio_error), sets_cache}
      end
    else
      {:error, message} -> {{:error, message}, sets_cache}
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
    case Repo.get_by(MeditationSet, name: set_name) do
      %MeditationSet{} = set ->
        {:ok, set}

      nil ->
        attrs = %{
          "name" => set_name,
          "category" => Map.get(row_map, "set_category"),
          "description" => Map.get(row_map, "set_description"),
          "labels" => parse_labels(Map.get(row_map, "set_labels"))
        }

        if opts[:dry_run] do
          validate_set_attrs(set_name, attrs)
        else
          case Rosary.create_meditation_set(attrs) do
            {:ok, set} -> {:ok, set}
            {:error, changeset} -> {:error, set_error(set_name, changeset)}
          end
        end
    end
  end

  defp validate_set_attrs(set_name, attrs) do
    changeset = MeditationSet.changeset(%MeditationSet{}, attrs)

    if changeset.valid? do
      {:ok, %MeditationSet{name: set_name}}
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
    changeset = Meditation.changeset(%Meditation{}, attrs)

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

  defp create_and_attach(attrs, row_map, mystery, set, audio_error) do
    case Rosary.create_meditation(attrs) do
      {:ok, meditation} ->
        case attach_to_set(set, meditation, row_map) do
          :ok ->
            created_result(attrs, mystery, set, audio_error)

          {:error, message} ->
            {:warning,
             "Created meditation for #{mystery.name} but failed to attach to set '#{set.name}': #{message}"}
        end

      {:error, changeset} ->
        {:error,
         "Failed to create meditation for '#{mystery.name}': #{changeset_errors(changeset)}"}
    end
  end

  defp created_result(attrs, mystery, set, audio_error) do
    title_info = if attrs["title"], do: " - #{attrs["title"]}", else: ""
    audio_info = if attrs["audio_url"], do: " (with audio)", else: ""
    set_info = if set, do: " [set: #{set.name}]", else: ""
    base = "Created meditation for #{mystery.name}#{title_info}#{audio_info}#{set_info}"

    case audio_error do
      nil -> {:ok, base}
      reason -> {:warning, "#{base} but audio generation failed: #{reason}"}
    end
  end

  defp attach_to_set(nil, _meditation, _row_map), do: :ok

  defp attach_to_set(set, meditation, row_map) do
    order = explicit_order(row_map) || next_order(set.id)

    case Rosary.add_meditation_to_set(set.id, meditation.id, order) do
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

  defp next_order(set_id) do
    current_max =
      Repo.one(
        from msm in MeditationSetMeditation,
          where: msm.meditation_set_id == ^set_id,
          select: max(msm.order)
      ) || 0

    current_max + 1
  end

  # Returns {attrs, audio_error}. When audio generation or upload fails the
  # meditation is still created (audio_error carries the reason so the row
  # result can surface it as a warning instead of hiding the failure).
  defp maybe_generate_audio(attrs, row_map, {index, total}, opts) do
    audio_filename = Map.get(row_map, "audio_filename")
    content = Map.get(attrs, "content")

    cond do
      opts[:skip_audio] ->
        {attrs, nil}

      is_nil(audio_filename) or is_nil(content) ->
        {attrs, nil}

      true ->
        notify(opts, {:row_audio, index, total, audio_filename})
        Logger.info("Generating audio for: #{audio_filename}")

        on_retry = fn attempt, max ->
          notify(opts, {:row_audio_retry, index, total, audio_filename, attempt, max})
        end

        case generate_and_upload_audio(content, audio_filename, on_retry) do
          {:ok, s3_key} ->
            Logger.info("Successfully generated and uploaded audio: #{s3_key}")
            {Map.put(attrs, "audio_url", s3_key), nil}

          {:error, reason} ->
            Logger.error("Failed to generate audio for #{audio_filename}: #{inspect(reason)}")
            {attrs, format_audio_error(reason)}
        end
    end
  end

  defp format_audio_error(reason) when is_binary(reason), do: reason
  defp format_audio_error(reason), do: reason |> inspect() |> String.slice(0, 200)

  # ElevenLabs in particular fails transiently, so both the generation call
  # and the S3 upload are retried with increasing backoff before giving up.
  # Errors tagged {:fatal, message} (bad API key, missing credentials, and
  # the like) are never retried because they cannot succeed.
  @audio_attempts 3
  @audio_retry_base_delay_ms 2_000

  defp generate_and_upload_audio(text, filename, on_retry) do
    with {:ok, audio_binary} <-
           with_retries(
             fn -> ElevenLabs.generate_audio(text) end,
             "ElevenLabs",
             filename,
             on_retry
           ),
         {:ok, s3_key} <-
           with_retries(
             fn -> S3.upload_audio(audio_binary, filename) end,
             "S3",
             filename,
             on_retry
           ) do
      {:ok, s3_key}
    else
      {:error, reason} = error ->
        Logger.error("Audio generation/upload failed: #{inspect(reason)}")
        error
    end
  end

  defp with_retries(fun, label, filename, on_retry, attempt \\ 1) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        case fatal_reason(reason) do
          nil ->
            maybe_retry(fun, label, filename, on_retry, attempt, reason)

          message ->
            Logger.error("#{label} failed for #{filename} (not retryable): #{message}")
            {:error, message}
        end
    end
  end

  defp maybe_retry(fun, label, filename, on_retry, attempt, reason)
       when attempt < @audio_attempts do
    delay = retry_delay(attempt)

    Logger.warning(
      "#{label} failed for #{filename} (attempt #{attempt} of #{@audio_attempts}): " <>
        "#{inspect(reason)}. Retrying in #{delay}ms"
    )

    on_retry.(attempt + 1, @audio_attempts)
    Process.sleep(delay)
    with_retries(fun, label, filename, on_retry, attempt + 1)
  end

  defp maybe_retry(_fun, label, filename, _on_retry, _attempt, reason) do
    Logger.error(
      "#{label} failed for #{filename} after #{@audio_attempts} attempts: #{inspect(reason)}"
    )

    {:error, reason}
  end

  defp fatal_reason({:fatal, message}), do: message

  defp fatal_reason(:missing_credentials),
    do: "AWS credentials not configured (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)"

  defp fatal_reason(_reason), do: nil

  defp retry_delay(attempt) do
    base =
      Application.get_env(:lumen_viae, :audio_retry_base_delay_ms, @audio_retry_base_delay_ms)

    base * attempt
  end

  defp notify(opts, event) do
    case opts[:progress] do
      fun when is_function(fun, 1) -> fun.(event)
      _ -> :ok
    end
  end

  defp changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
    |> Enum.join("; ")
  end
end
