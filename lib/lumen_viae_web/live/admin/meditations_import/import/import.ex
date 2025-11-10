defmodule LumenViaeWeb.Live.Admin.MeditationsImport.Import do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

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
      attrs = %{
        "mystery_id" => mystery.id,
        "title" => Map.get(row, "title"),
        "content" => Map.get(row, "content"),
        "author" => Map.get(row, "author"),
        "source" => Map.get(row, "source")
      }

      case Rosary.create_meditation(attrs) do
        {:ok, _meditation} ->
          title_info = if attrs["title"], do: " - #{attrs["title"]}", else: ""
          {:ok, "Created meditation for #{mystery.name}#{title_info}"}

        {:error, changeset} ->
          errors =
            changeset
            |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
            |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
            |> Enum.join("; ")

          {:error, "Failed to create meditation for '#{mystery_name}': #{errors}"}
      end
    else
      {:error, "Mystery not found: #{mystery_name}. Make sure the mystery name exactly matches an existing mystery."}
    end
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted. Please upload a CSV file"
  defp error_to_string(:too_many_files), do: "Too many files selected. Please upload only one CSV file"
end
