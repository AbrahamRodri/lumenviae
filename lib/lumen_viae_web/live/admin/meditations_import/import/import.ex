defmodule LumenViaeWeb.Live.Admin.MeditationsImport.Import do
  use LumenViaeWeb, :live_view

  alias LumenViae.Meditations.CsvImport
  alias LumenViae.Rosary.Labels

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import Meditations from CSV")
     |> assign(:uploaded_files, [])
     |> assign(:errors, [])
     |> assign(:successes, [])
     |> assign(:label_vocabulary, Labels.vocabulary())
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
        {:ok, CsvImport.import_file(path)}
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

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted. Please upload a CSV file"

  defp error_to_string(:too_many_files),
    do: "Too many files selected. Please upload only one CSV file"
end
