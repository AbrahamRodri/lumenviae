defmodule LumenViaeWeb.Live.Admin.MeditationsImport.Import do
  use LumenViaeWeb, :live_view

  alias LumenViae.Meditations.CsvImport
  alias LumenViae.Rosary.Labels

  # Import flow stages:
  #   :idle      - waiting for a file
  #   :ready     - file parsed, preview shown, awaiting confirmation
  #   :importing - async import running, progress streaming in
  #   :done      - finished (successfully, with errors, or cancelled)

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import Meditations from CSV")
     |> assign(:label_vocabulary, Labels.vocabulary())
     |> assign_initial_state()
     |> allow_upload(:csv, accept: ~w(.csv), max_entries: 1)}
  end

  defp assign_initial_state(socket) do
    socket
    |> assign(:stage, :idle)
    |> assign(:csv_content, nil)
    |> assign(:csv_filename, nil)
    |> assign(:preview, nil)
    |> assign(:preview_error, nil)
    |> assign(:rows_status, %{})
    |> assign(:progress, %{done: 0, total: 0})
    |> assign(:current_activity, nil)
    |> assign(:skip_audio, false)
    |> assign(:elapsed, 0)
    |> assign(:cancelled, false)
    |> assign(:successes, [])
    |> assign(:errors, [])
  end

  ## Events

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("remove-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv, ref)}
  end

  def handle_event("preview", _params, socket) do
    case consume_csv_upload(socket) do
      {:ok, filename, content} ->
        case CsvImport.preview_string(content) do
          {:ok, preview} ->
            {:noreply,
             socket
             |> assign(:stage, :ready)
             |> assign(:csv_content, content)
             |> assign(:csv_filename, filename)
             |> assign(:preview, preview)
             |> assign(:preview_error, nil)}

          {:error, message} ->
            {:noreply, socket |> assign(:stage, :idle) |> assign(:preview_error, message)}
        end

      :no_file ->
        {:noreply, assign(socket, :preview_error, "Please choose a CSV file first")}
    end
  end

  def handle_event("toggle-skip-audio", _params, socket) do
    {:noreply, assign(socket, :skip_audio, not socket.assigns.skip_audio)}
  end

  def handle_event("start-import", _params, %{assigns: %{stage: :ready}} = socket) do
    live_view = self()
    content = socket.assigns.csv_content
    opts = [
      skip_audio: socket.assigns.skip_audio,
      progress: fn event -> send(live_view, {:import_progress, event}) end
    ]

    Process.send_after(self(), :tick, 1_000)

    {:noreply,
     socket
     |> assign(:stage, :importing)
     |> assign(:rows_status, %{})
     |> assign(:progress, %{done: 0, total: socket.assigns.preview.total})
     |> assign(:current_activity, "Starting import...")
     |> assign(:elapsed, 0)
     |> start_async(:import, fn -> CsvImport.import_string(content, opts) end)}
  end

  def handle_event("start-import", _params, socket), do: {:noreply, socket}

  def handle_event("cancel-import", _params, %{assigns: %{stage: :importing}} = socket) do
    {:noreply,
     socket
     |> cancel_async(:import)
     |> assign(:stage, :done)
     |> assign(:cancelled, true)
     |> assign(:current_activity, nil)
     |> collect_results_from_status()}
  end

  def handle_event("cancel-import", _params, socket), do: {:noreply, socket}

  def handle_event("reset", _params, socket) do
    {:noreply, assign_initial_state(socket)}
  end

  ## Async import lifecycle

  def handle_async(:import, {:ok, results}, socket) do
    successes = Enum.filter(results, fn {status, _} -> status == :ok end)
    errors = Enum.filter(results, fn {status, _} -> status == :error end)

    {:noreply,
     socket
     |> assign(:stage, :done)
     |> assign(:current_activity, nil)
     |> assign(:successes, successes)
     |> assign(:errors, errors)}
  end

  def handle_async(:import, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:stage, :done)
     |> assign(:current_activity, nil)
     |> collect_results_from_status()
     |> update(:errors, &(&1 ++ [{:error, "Import crashed: #{inspect(reason)}"}]))}
  end

  ## Progress messages from the import engine

  def handle_info({:import_progress, {:started, total}}, socket) do
    {:noreply, assign(socket, :progress, %{done: 0, total: total})}
  end

  def handle_info({:import_progress, {:row_started, index, total, description}}, socket) do
    {:noreply,
     socket
     |> update(:rows_status, &Map.put(&1, index, {:working, description}))
     |> assign(:current_activity, "Row #{index} of #{total}: creating #{description}")}
  end

  def handle_info({:import_progress, {:row_audio, index, total, filename}}, socket) do
    {:noreply,
     socket
     |> update(:rows_status, &Map.put(&1, index, {:audio, filename}))
     |> assign(
       :current_activity,
       "Row #{index} of #{total}: generating audio #{filename} (this is the slow part)"
     )}
  end

  def handle_info(
        {:import_progress, {:row_audio_retry, index, total, filename, attempt, max}},
        socket
      ) do
    {:noreply,
     socket
     |> update(:rows_status, &Map.put(&1, index, {:audio, filename}))
     |> assign(
       :current_activity,
       "Row #{index} of #{total}: audio for #{filename} failed, retrying (attempt #{attempt} of #{max})"
     )}
  end

  def handle_info({:import_progress, {:row_finished, index, _total, result}}, socket) do
    {:noreply,
     socket
     |> update(:rows_status, &Map.put(&1, index, result))
     |> update(:progress, fn progress -> %{progress | done: progress.done + 1} end)}
  end

  def handle_info(:tick, %{assigns: %{stage: :importing}} = socket) do
    Process.send_after(self(), :tick, 1_000)
    {:noreply, update(socket, :elapsed, &(&1 + 1))}
  end

  def handle_info(:tick, socket), do: {:noreply, socket}

  ## Helpers

  defp consume_csv_upload(socket) do
    case uploaded_entries(socket, :csv) do
      {[_ | _], _} ->
        [{filename, content}] =
          consume_uploaded_entries(socket, :csv, fn %{path: path}, entry ->
            {:ok, {entry.client_name, File.read!(path)}}
          end)

        {:ok, filename, content}

      _ ->
        :no_file
    end
  end

  # When an import is cancelled or crashes mid-run, salvage the per-row
  # results received so far so the operator can see what was written.
  defp collect_results_from_socket_status(rows_status) do
    rows_status
    |> Enum.sort_by(fn {index, _} -> index end)
    |> Enum.flat_map(fn
      {_index, {:ok, message}} -> [{:ok, message}]
      {_index, {:error, message}} -> [{:error, message}]
      _ -> []
    end)
  end

  defp collect_results_from_status(socket) do
    results = collect_results_from_socket_status(socket.assigns.rows_status)

    socket
    |> assign(:successes, Enum.filter(results, fn {status, _} -> status == :ok end))
    |> assign(:errors, Enum.filter(results, fn {status, _} -> status == :error end))
  end

  def percent(%{done: _, total: 0}), do: 0
  def percent(%{done: done, total: total}), do: trunc(done / total * 100)

  def format_elapsed(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [minutes, secs]) |> to_string()
  end

  def row_status(rows_status, index), do: Map.get(rows_status, index, :pending)

  def status_badge(:pending), do: {"bg-gray-100 text-gray-500", "Waiting"}
  def status_badge({:working, _}), do: {"bg-gold/20 text-navy animate-pulse", "Creating"}
  def status_badge({:audio, _}), do: {"bg-blue-100 text-blue-800 animate-pulse", "Audio"}
  def status_badge({:ok, _}), do: {"bg-green-100 text-green-800", "Done"}
  def status_badge({:error, _}), do: {"bg-red-100 text-red-800", "Failed"}

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted. Please upload a CSV file"

  defp error_to_string(:too_many_files),
    do: "Too many files selected. Please upload only one CSV file"
end
