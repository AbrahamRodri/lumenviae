defmodule LumenViae.Curation.CsvUpdate do
  @moduledoc """
  Replaces the text of meditations that already exist, from a CSV, and
  re-records their narration.

  The import creates; this edits. A curated row that is re-cut after it
  shipped - a better opening, a passage extended to its real ending, a
  re-sourced excerpt - used to mean deleting the live row in the admin and
  importing a one-row fix CSV, which changed the meditation's id and
  dropped it from its set. Here the row keeps its id, its set membership,
  its order and its audio filename; only the words change, and every
  voice's recording is regenerated from them, as narration jobs
  (`LumenViae.Curation.AudioRegeneration`) that finish after the update
  returns.

  ## CSV format

  Required columns:

    * `meditation_id` - the id of the meditation to change
    * `content` - the new text, with the same `{pause:N}` markers the
      import accepts (see `LumenViae.Curation.CsvImport`)

  Optional columns, each replacing the column of the same name when
  present and left alone when the cell is empty:

    * `title`
    * `author`
    * `source`

  ## Options

    * `:dry_run` - validate and describe each change without writing
      anything or calling ElevenLabs
    * `:skip_audio` - write the text but leave the recordings as they are
    * `:voices` - slugs of the voices to re-record (default: every
      configured voice)
    * `:batch` - the batch the narration jobs are enqueued under; pass one
      to follow them
    * `:progress` - a 1-arity function receiving `{:started, total}` and
      `{:row_finished, index, total, result}`
    * `:actor` - the admin the update runs as; the console passes the
      signed-in admin
    * `:authorize?` - `false` only from an operator's shell (mix tasks,
      `LumenViae.Release`), which already holds the database

  Results are `{:ok | :warning | :error, message}` tuples in row order. A
  `:warning` means the text was written but a recording could not be
  queued. A recording that is queued and then fails is the batch's to
  report; either way the meditation keeps its old recording in that voice
  until `regenerate_audio` replaces it.
  """

  alias LumenViae.AshOpts
  alias LumenViae.Audio.TtsText
  alias LumenViae.Curation.AudioRegeneration
  alias LumenViae.Rosary

  NimbleCSV.define(LumenViae.Curation.CsvUpdate.Parser, separator: ",", escape: "\"")

  alias LumenViae.Curation.CsvUpdate.Parser

  @required_columns ~w(meditation_id content)
  @known_columns ~w(meditation_id title content author source)

  def update_file(path, opts \\ []) do
    case File.read(path) do
      {:ok, content} -> update_string(content, opts)
      {:error, reason} -> [{:error, "Failed to read file: #{inspect(reason)}"}]
    end
  end

  def update_string(content, opts \\ []) do
    case parse(content) do
      {:error, message} ->
        [{:error, message}]

      {:ok, headers, rows} ->
        total = length(rows)
        notify(opts, {:started, total})

        rows
        |> Enum.with_index(1)
        |> Enum.map(fn {row, index} ->
          result = process_row(headers, row, opts)
          notify(opts, {:row_finished, index, total, result})
          result
        end)
    end
  end

  ## Parsing

  defp parse(content) do
    content = String.replace_prefix(content, "﻿", "")

    case Parser.parse_string(content, skip_headers: false) do
      [] ->
        {:error, "CSV is empty"}

      [headers | rows] ->
        headers = Enum.map(headers, &String.trim/1)
        missing = @required_columns -- headers
        unknown = headers -- @known_columns

        cond do
          missing != [] ->
            {:error, "CSV is missing required column(s): #{Enum.join(missing, ", ")}"}

          unknown != [] ->
            {:error, "CSV has unknown column(s): #{Enum.join(unknown, ", ")}"}

          true ->
            {:ok, headers, Enum.reject(rows, &blank_row?/1)}
        end
    end
  end

  defp blank_row?(row), do: Enum.all?(row, &(String.trim(&1) == ""))

  defp row_to_map(headers, row) do
    headers
    |> Enum.zip(row ++ List.duplicate("", max(length(headers) - length(row), 0)))
    |> Map.new(fn {header, value} ->
      trimmed = String.trim(value)
      {header, if(trimmed == "", do: nil, else: trimmed)}
    end)
  end

  ## Rows

  defp process_row(headers, row, opts) do
    row_map = row_to_map(headers, row)

    with {:ok, meditation} <- fetch_meditation(row_map["meditation_id"], opts),
         {:ok, clean_content, annotations} <- extract_content(row_map["content"], meditation) do
      attrs =
        %{"content" => clean_content, "tts_annotations" => annotations}
        |> put_optional("title", row_map["title"])
        |> put_optional("author", row_map["author"])
        |> put_optional("source", row_map["source"])

      if opts[:dry_run] do
        dry_run_result(meditation, attrs, opts)
      else
        apply_update(meditation, attrs, opts)
      end
    end
  end

  defp put_optional(attrs, _key, nil), do: attrs
  defp put_optional(attrs, key, value), do: Map.put(attrs, key, value)

  defp fetch_meditation(nil, _opts), do: {:error, "Row is missing meditation_id"}

  defp fetch_meditation(id, opts) do
    case Integer.parse(id) do
      {meditation_id, ""} ->
        case Rosary.get_meditation(meditation_id, AshOpts.take(opts)) do
          {:ok, meditation} -> {:ok, meditation}
          {:error, _not_found} -> {:error, "Meditation not found: id #{meditation_id}"}
        end

      _ ->
        {:error, "meditation_id is not a number: #{inspect(id)}"}
    end
  end

  defp extract_content(nil, meditation),
    do: {:error, "#{describe(meditation)}: row has no content"}

  defp extract_content(raw, meditation) do
    case TtsText.extract_pauses(raw) do
      {:ok, clean, annotations} -> {:ok, clean, annotations}
      {:error, message} -> {:error, "#{describe(meditation)}: #{message}"}
    end
  end

  defp dry_run_result(meditation, attrs, opts) do
    changeset = Rosary.changeset_to_update_meditation(meditation, attrs, AshOpts.take(opts))

    if changeset.valid? do
      {:ok, "Would update #{describe(meditation)}: #{summarize(meditation, attrs)}"}
    else
      {:error, "Invalid update for #{describe(meditation)}: #{changeset_errors(changeset)}"}
    end
  end

  defp apply_update(meditation, attrs, opts) do
    case Rosary.update_meditation(meditation, attrs, AshOpts.take(opts)) do
      {:ok, updated} ->
        base = "Updated #{describe(meditation)}: #{summarize(meditation, attrs)}"

        if opts[:skip_audio] do
          {:ok, base <> " (audio not regenerated)"}
        else
          case narrate(updated, opts) do
            :ok ->
              {:ok, base <> " and queued its narration"}

            {:error, failures} ->
              {:warning, base <> " but narration was not queued: " <> failures}
          end
        end

      {:error, changeset} ->
        {:error, "Failed to update #{describe(meditation)}: #{changeset_errors(changeset)}"}
    end
  end

  # Every voice, through the same regeneration the mix task uses, so the
  # recordings and the narration rows stay in step with the new words. A
  # meditation with no audio filename is reported as a warning by it.
  defp narrate(meditation, opts) do
    results =
      AudioRegeneration.run(
        {:meditation, meditation.id},
        [voices: opts[:voices], batch: opts[:batch]] ++ AshOpts.take(opts)
      )

    case Enum.reject(results, &match?({:ok, _}, &1)) do
      [] -> :ok
      failures -> {:error, Enum.map_join(failures, "; ", fn {_status, message} -> message end)}
    end
  end

  defp summarize(meditation, attrs) do
    title =
      case attrs["title"] do
        nil -> nil
        new -> "title #{inspect(meditation.title)} -> #{inspect(new)}"
      end

    words = "#{word_count(meditation.content)} -> #{word_count(attrs["content"])} words"
    pauses = "#{length(attrs["tts_annotations"])} custom pause(s)"
    source = if attrs["source"], do: "new source", else: nil

    [title, words, pauses, source] |> Enum.reject(&is_nil/1) |> Enum.join(", ")
  end

  defp word_count(nil), do: 0
  defp word_count(text), do: text |> String.split(~r/\s+/, trim: true) |> length()

  defp describe(meditation) do
    label = meditation.title || mystery_name(meditation.mystery)

    if label, do: "meditation #{meditation.id} (#{label})", else: "meditation #{meditation.id}"
  end

  # Not Ecto.assoc_loaded?/1: it answers true for anything that is not
  # Ecto's own not-loaded marker, Ash's included, and the label would then
  # crash reading a name off a relationship that was never loaded.
  defp mystery_name(%{name: name}), do: name
  defp mystery_name(_not_loaded_or_nil), do: nil

  defp changeset_errors(error), do: Rosary.error_summary(error)

  defp notify(opts, event) do
    case opts[:progress] do
      fun when is_function(fun, 1) -> fun.(event)
      _ -> :ok
    end
  end
end
