defmodule LumenViae.Meditations.CsvImport do
  @moduledoc """
  Shared CSV import engine for meditations and meditation sets.

  Used by both the admin LiveView upload flow and the `mix lumen_viae.import`
  task, so batch imports behave identically whether they come through the
  browser or from Claude Code / the command line.

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

  Optional meditation set columns (added with the labels schema update):

    * `set_name` - find-or-create a meditation set with this name and attach
      the row's meditation to it
    * `set_category` - required when the set does not exist yet; one of
      joyful, sorrowful, glorious, seven_sorrows
    * `set_description` - set description (used on create only)
    * `set_labels` - pipe-separated labels from the managed vocabulary
      (see `LumenViae.Rosary.Labels`), e.g. "Saints|Contemplative"; order
      matters, the first label is the set's primary group (create only)
    * `order` - explicit position of the meditation within the set; when
      omitted, rows are appended after the set's current highest order

  ## Options

    * `:skip_audio` - when true, `audio_filename` columns are ignored and no
      ElevenLabs/S3 calls are made
    * `:dry_run` - when true, validates rows (mystery lookup, changesets,
      label vocabulary) without writing to the database or generating audio

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
    case Parser.parse_string(content, skip_headers: false) do
      [] ->
        [{:error, "CSV file is empty"}]

      [headers | rows] ->
        headers = Enum.map(headers, &(&1 |> String.trim() |> String.downcase()))
        process_rows(headers, rows, opts)
    end
  end

  defp process_rows(_headers, [], _opts), do: [{:error, "CSV file has no data rows"}]

  defp process_rows(headers, rows, opts) do
    mysteries = Rosary.list_mysteries() |> Enum.group_by(& &1.name)

    {results, _sets_cache} =
      Enum.map_reduce(rows, %{}, fn row, sets_cache ->
        row_map = headers |> Enum.zip(row) |> Map.new() |> normalize_row()
        process_row(row_map, mysteries, sets_cache, opts)
      end)

    results
  end

  defp normalize_row(row_map) do
    Map.new(row_map, fn {key, value} ->
      value = value |> to_string() |> String.trim()
      {key, if(value == "", do: nil, else: value)}
    end)
  end

  defp process_row(row_map, mysteries, sets_cache, opts) do
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
        attrs = maybe_generate_audio(attrs, row_map, opts)
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

    cond do
      not changeset.valid? ->
        {:error, "Invalid meditation for '#{mystery.name}': #{changeset_errors(changeset)}"}

      true ->
        set_info = if set, do: " -> set '#{set.name}'#{order_info(row_map)}", else: ""
        audio_info = if Map.get(row_map, "audio_filename"), do: " (audio)", else: ""
        {:ok, "Would create meditation for #{mystery.name}#{set_info}#{audio_info}"}
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

  defp maybe_generate_audio(attrs, row_map, opts) do
    audio_filename = Map.get(row_map, "audio_filename")
    content = Map.get(attrs, "content")

    cond do
      opts[:skip_audio] ->
        attrs

      is_nil(audio_filename) or is_nil(content) ->
        attrs

      true ->
        Logger.info("Generating audio for: #{audio_filename}")

        case generate_and_upload_audio(content, audio_filename) do
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

  defp generate_and_upload_audio(text, filename) do
    with {:ok, audio_binary} <- ElevenLabs.generate_audio(text),
         {:ok, s3_key} <- S3.upload_audio(audio_binary, filename) do
      {:ok, s3_key}
    else
      {:error, reason} = error ->
        Logger.error("Audio generation/upload failed: #{inspect(reason)}")
        error
    end
  end

  defp changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
    |> Enum.join("; ")
  end
end
