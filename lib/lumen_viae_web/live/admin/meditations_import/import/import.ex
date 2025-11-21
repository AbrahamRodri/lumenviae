defmodule LumenViaeWeb.Live.Admin.MeditationsImport.Import do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary
  alias LumenViae.Audio.ElevenLabs
  alias LumenViae.Storage.S3

  require Logger

  NimbleCSV.define(MyParser, separator: ",", escape: "\"")

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import Meditations from CSV")
     |> assign(:uploaded_files, [])
     |> assign(:errors, [])
     |> assign(:successes, [])
     |> allow_upload(:csv, accept: ~w(.csv), max_entries: 1)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("remove-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv, ref)}
  end

  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        {:ok, parse_csv_file(path)}
      end)

    results = List.flatten(uploaded_files)

    successes = Enum.filter(results, fn {status, _} -> status == :ok end)
    errors = Enum.filter(results, fn {status, _} -> status == :error end)

    {:noreply,
     socket
     |> assign(:successes, successes)
     |> assign(:errors, errors)
     |> update(:uploaded_files, &(&1 ++ uploaded_files))}
  end

  defp parse_csv_file(path) do
    case File.read(path) do
      {:ok, content} ->
        content
        |> MyParser.parse_string(skip_headers: false)
        |> process_csv_rows()

      {:error, reason} ->
        [{:error, "Failed to read file: #{inspect(reason)}"}]
    end
  end

  defp process_csv_rows([headers | rows]) do
    headers = Enum.map(headers, &String.downcase/1)
    # Get all mysteries upfront for lookup
    mysteries = Rosary.list_mysteries() |> Enum.group_by(& &1.name)

    Enum.map(rows, fn row -> process_row(headers, row, mysteries) end)
  end

  defp process_csv_rows([]) do
    [{:error, "CSV file is empty"}]
  end

  defp process_row(headers, values, mysteries) do
    row = Enum.zip(headers, values) |> Map.new()

    mystery_name = Map.get(row, "mystery_name")
    mystery = get_in(mysteries, [mystery_name, Access.at(0)])

    if mystery do
      # Build base attributes
      attrs = %{
        "mystery_id" => mystery.id,
        "title" => Map.get(row, "title"),
        "content" => Map.get(row, "content"),
        "author" => Map.get(row, "author"),
        "source" => Map.get(row, "source")
      }

      # Generate and upload audio if audio_filename is provided
      attrs_with_audio = maybe_generate_audio(attrs, row)

      case Rosary.create_meditation(attrs_with_audio) do
        {:ok, _meditation} ->
          title_info = if attrs_with_audio["title"], do: " - #{attrs_with_audio["title"]}", else: ""
          audio_info = if attrs_with_audio["audio_url"], do: " (with audio)", else: ""
          {:ok, "Created meditation for #{mystery.name}#{title_info}#{audio_info}"}

        {:error, changeset} ->
          errors =
            changeset
            |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
            |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
            |> Enum.join("; ")

          {:error, "Failed to create meditation for '#{mystery_name}': #{errors}"}
      end
    else
      {:error,
       "Mystery not found: #{mystery_name}. Make sure the mystery name exactly matches an existing mystery."}
    end
  end

  defp maybe_generate_audio(attrs, row) do
    audio_filename = Map.get(row, "audio_filename")
    content = Map.get(attrs, "content")

    # Only generate audio if both audio_filename and content are present
    if audio_filename && content && String.trim(audio_filename) != "" do
      Logger.info("Generating audio for: #{audio_filename}")

      case generate_and_upload_audio(content, audio_filename) do
        {:ok, s3_key} ->
          Logger.info("Successfully generated and uploaded audio: #{s3_key}")
          Map.put(attrs, "audio_url", s3_key)

        {:error, reason} ->
          Logger.error("Failed to generate audio for #{audio_filename}: #{inspect(reason)}")
          # Still create the meditation without audio rather than failing the entire import
          attrs
      end
    else
      attrs
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

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted. Please upload a CSV file"

  defp error_to_string(:too_many_files),
    do: "Too many files selected. Please upload only one CSV file"
end
