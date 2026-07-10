defmodule LumenViae.Meditations.CsvImport do
  @moduledoc """
  Shared CSV import engine for meditations and meditation sets.

  Used by the admin LiveView upload flow, the `mix lumen_viae.import` task,
  and `LumenViae.Release.import_csv/2`, so batch imports behave identically
  whether they come through the browser or the command line.

  ## CSV format

  Required columns:

    * `mystery_name` - must exactly match an existing mystery name
    * `content` - the meditation text

  Optional meditation columns:

    * `title` - meditation title
    * `author` - meditation author
    * `source` - meditation source
    * `audio_filename` - when present, audio is generated with ElevenLabs and
      uploaded to S3 under this key; the meditation is still created if audio
      generation fails

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
    * `{:row_finished, index, total, {:ok | :error, message}}` - row result

  Results are returned as a list of `{:ok, message}` / `{:error, message}`
  tuples, in row order.
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
        set_statuses = preview_set_statuses(headers, rows)

        row_infos =
          rows
          |> Enum.with_index(1)
          |> Enum.map(fn {row, index} ->
            row_map = headers |> Enum.zip(row) |> Map.new() |> normalize_row()
            preview_row(index, row_map, mysteries, set_statuses)
          end)

        {:ok,
         %{
           rows: row_infos,
           total: length(row_infos),
           valid_count: Enum.count(row_infos, &(&1.errors == [])),
           error_count: Enum.count(row_infos, &(&1.errors != [])),
           audio_count: Enum.count(row_infos, & &1.audio_filename),
           new_sets:
             for({name, {:new, _}} <- set_statuses, do: name) |> Enum.sort(),
           existing_sets:
             for({name, {:existing, _}} <- set_statuses, do: name) |> Enum.sort()
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

  defp preview_set_statuses(headers, rows) do
    rows
    |> Enum.map(fn row -> headers |> Enum.zip(row) |> Map.new() |> normalize_row() end)
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

  defp preview_row(index, row_map, mysteries, set_statuses) do
    mystery_name = Map.get(row_map, "mystery_name")
    mystery_ok = mystery_name && get_in(mysteries, [mystery_name, Access.at(0)]) != nil
    content = Map.get(row_map, "content")
    set_name = Map.get(row_map, "set_name")

    {set_status, set_errors} =
      case set_statuses[set_name] do
        nil -> {nil, []}
        {status, errors} -> {status, errors}
      end

    errors =
      []
      |> then(fn errs ->
        cond do
          is_nil(mystery_name) -> ["missing mystery_name" | errs]
          not mystery_ok -> ["mystery not found: #{mystery_name}" | errs]
          true -> errs
        end
      end)
      |> then(fn errs -> if is_nil(content), do: ["missing content" | errs], else: errs end)
      |> Kernel.++(set_errors)

    warnings =
      []
      |> then(fn warns ->
        if content && not String.contains?(content, "\n\n"),
          do: ["no paragraph breaks (see curation guide)" | warns],
          else: warns
      end)
      |> then(fn warns ->
        if content && String.length(content) > 2500,
          do: ["long content: audio will be lengthy and costly" | warns],
          else: warns
      end)

    %{
      index: index,
      mystery_name: mystery_name,
      mystery_ok: mystery_ok,
      title: Map.get(row_map, "title"),
      author: Map.get(row_map, "author"),
      content_chars: (content && String.length(content)) || 0,
      paragraphs: (content && String.split(content, "\n\n") |> length()) || 0,
      content_excerpt: content_excerpt(content),
      audio_filename: Map.get(row_map, "audio_filename"),
      set_name: set_name,
      set_status: set_status,
      set_labels: parse_labels(Map.get(row_map, "set_labels")),
      order: Map.get(row_map, "order"),
      errors: Enum.reverse(errors),
      warnings: Enum.reverse(warnings)
    }
  end

  defp content_excerpt(nil), do: nil

  defp content_excerpt(content) do
    flat = content |> String.replace(~r/\s+/, " ") |> String.trim()
    if String.length(flat) > 160, do: String.slice(flat, 0, 160) <> "...", else: flat
  end

  ## Shared parsing

  defp parse(content) do
    case Parser.parse_string(content, skip_headers: false) do
      [] ->
        {:error, "CSV file is empty"}

      [headers | rows] ->
        headers = Enum.map(headers, &(&1 |> String.trim() |> String.downcase()))

        if rows == [] do
          {:error, "CSV file has no data rows"}
        else
          {:ok, headers, rows}
        end
    end
  end

  ## Row processing

  defp process_rows(headers, rows, opts) do
    mysteries = Rosary.list_mysteries() |> Enum.group_by(& &1.name)
    total = length(rows)
    notify(opts, {:started, total})

    {results, _sets_cache} =
      rows
      |> Enum.with_index(1)
      |> Enum.map_reduce(%{}, fn {row, index}, sets_cache ->
        row_map = headers |> Enum.zip(row) |> Map.new() |> normalize_row()
        description = Map.get(row_map, "mystery_name") || "row #{index}"
        notify(opts, {:row_started, index, total, description})

        {result, sets_cache} = process_row(row_map, mysteries, sets_cache, {index, total}, opts)
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
        {dry_run_result(attrs, row_map, mystery, set), sets_cache}
      else
        attrs = maybe_generate_audio(attrs, row_map, {index, total}, opts)
        {create_and_attach(attrs, row_map, mystery, set), sets_cache}
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

  defp dry_run_result(attrs, row_map, mystery, set) do
    changeset = Meditation.changeset(%Meditation{}, attrs)

    if changeset.valid? do
      set_info = if set, do: " -> set '#{set.name}'#{order_info(row_map)}", else: ""
      audio_info = if Map.get(row_map, "audio_filename"), do: " (audio)", else: ""
      {:ok, "Would create meditation for #{mystery.name}#{set_info}#{audio_info}"}
    else
      {:error, "Invalid meditation for '#{mystery.name}': #{changeset_errors(changeset)}"}
    end
  end

  defp order_info(row_map) do
    case Map.get(row_map, "order") do
      nil -> ""
      order -> " at order #{order}"
    end
  end

  defp create_and_attach(attrs, row_map, mystery, set) do
    case Rosary.create_meditation(attrs) do
      {:ok, meditation} ->
        case attach_to_set(set, meditation, row_map) do
          :ok ->
            title_info = if attrs["title"], do: " - #{attrs["title"]}", else: ""
            audio_info = if attrs["audio_url"], do: " (with audio)", else: ""
            set_info = if set, do: " [set: #{set.name}]", else: ""
            {:ok, "Created meditation for #{mystery.name}#{title_info}#{audio_info}#{set_info}"}

          {:error, message} ->
            {:error,
             "Created meditation for #{mystery.name} but failed to attach to set: #{message}"}
        end

      {:error, changeset} ->
        {:error,
         "Failed to create meditation for '#{mystery.name}': #{changeset_errors(changeset)}"}
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

  defp maybe_generate_audio(attrs, row_map, {index, total}, opts) do
    audio_filename = Map.get(row_map, "audio_filename")
    content = Map.get(attrs, "content")

    cond do
      opts[:skip_audio] ->
        attrs

      is_nil(audio_filename) or is_nil(content) ->
        attrs

      true ->
        notify(opts, {:row_audio, index, total, audio_filename})
        Logger.info("Generating audio for: #{audio_filename}")

        on_retry = fn attempt, max ->
          notify(opts, {:row_audio_retry, index, total, audio_filename, attempt, max})
        end

        case generate_and_upload_audio(content, audio_filename, on_retry) do
          {:ok, s3_key} ->
            Logger.info("Successfully generated and uploaded audio: #{s3_key}")
            Map.put(attrs, "audio_url", s3_key)

          {:error, reason} ->
            Logger.error("Failed to generate audio for #{audio_filename}: #{inspect(reason)}")
            # Still create the meditation without audio rather than failing the row.
            attrs
        end
    end
  end

  # ElevenLabs in particular fails transiently, so both the generation call
  # and the S3 upload are retried with increasing backoff before giving up.
  @audio_attempts 3
  @audio_retry_base_delay_ms 2_000

  defp generate_and_upload_audio(text, filename, on_retry) do
    with {:ok, audio_binary} <-
           with_retries(fn -> ElevenLabs.generate_audio(text) end, "ElevenLabs", filename, on_retry),
         {:ok, s3_key} <-
           with_retries(fn -> S3.upload_audio(audio_binary, filename) end, "S3", filename, on_retry) do
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

      {:error, reason} when attempt < @audio_attempts ->
        delay = @audio_retry_base_delay_ms * attempt

        Logger.warning(
          "#{label} failed for #{filename} (attempt #{attempt} of #{@audio_attempts}): " <>
            "#{inspect(reason)}. Retrying in #{delay}ms"
        )

        on_retry.(attempt + 1, @audio_attempts)
        Process.sleep(delay)
        with_retries(fun, label, filename, on_retry, attempt + 1)

      {:error, reason} ->
        Logger.error(
          "#{label} failed for #{filename} after #{@audio_attempts} attempts: #{inspect(reason)}"
        )

        {:error, reason}
    end
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
