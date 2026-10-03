defmodule LumenViaeWeb.Live.Admin.MeditationsImport.Import do
  use LumenViaeWeb, :live_view

  alias LumenViae.Curation.{AudioJobs, CsvImport}
  alias LumenViae.Rosary.Labels

  # Import flow stages:
  #   :idle      - waiting for a file
  #   :ready     - file parsed, preview shown, awaiting confirmation
  #   :importing - async import running, progress streaming in
  #   :done      - finished (successfully, with errors, or cancelled)
  #
  # The rows are written during :importing; each narration is a job that
  # finishes afterwards, often after :done. The page subscribes to the
  # import's batch and follows the recordings as they land, whatever the
  # stage (see LumenViae.Curation.AudioJobs).

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
    |> assign(:warnings, [])
    |> assign(:errors, [])
    |> assign(:batch, nil)
    |> assign(:recordings, %{})
    |> assign(:recording_keys, [])
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
        case CsvImport.preview_string(content, actor: socket.assigns.current_admin) do
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
    batch = AudioJobs.new_batch()
    if connected?(socket), do: AudioJobs.subscribe(batch)

    opts = [
      actor: socket.assigns.current_admin,
      batch: batch,
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
     |> assign(:batch, batch)
     |> assign(:recordings, %{})
     |> assign(:recording_keys, [])
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
    if socket.assigns.batch, do: AudioJobs.unsubscribe(socket.assigns.batch)
    {:noreply, assign_initial_state(socket)}
  end

  ## Async import lifecycle

  def handle_async(:import, {:ok, results}, socket) do
    {:noreply,
     socket
     |> assign(:stage, :done)
     |> assign(:current_activity, nil)
     |> assign_grouped_results(results)}
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

  def handle_info({:import_progress, {:row_audio, index, total, key}}, socket) do
    {:noreply,
     socket
     |> update(:rows_status, &Map.put(&1, index, {:audio, key}))
     |> update(:recordings, &Map.put_new(&1, key, %{status: :queued, message: nil}))
     |> update(:recording_keys, &if(key in &1, do: &1, else: &1 ++ [key]))
     |> assign(:current_activity, "Row #{index} of #{total}: queueing narration #{key}")}
  end

  # A narration job of this import's batch finished, or is retrying.
  def handle_info({:audio_job, %{key: key} = event}, socket) do
    {:noreply,
     socket
     |> update(:recordings, &Map.put(&1, key, Map.take(event, [:status, :message])))
     |> update(:recording_keys, &if(key in &1, do: &1, else: &1 ++ [key]))}
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
      {_index, {:warning, message}} -> [{:warning, message}]
      {_index, {:error, message}} -> [{:error, message}]
      _ -> []
    end)
  end

  defp collect_results_from_status(socket) do
    results = collect_results_from_socket_status(socket.assigns.rows_status)
    assign_grouped_results(socket, results)
  end

  defp assign_grouped_results(socket, results) do
    grouped = Enum.group_by(results, fn {status, _} -> status end)

    socket
    |> assign(:successes, Map.get(grouped, :ok, []))
    |> assign(:warnings, Map.get(grouped, :warning, []))
    |> assign(:errors, Map.get(grouped, :error, []))
  end

  def percent(%{done: _, total: 0}), do: 0
  def percent(%{done: done, total: total}), do: trunc(done / total * 100)

  def format_elapsed(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [minutes, secs]) |> to_string()
  end

  def row_status(rows_status, index), do: Map.get(rows_status, index, :pending)

  @doc "The batch's recordings counted by where they are."
  def recording_counts(recordings) do
    statuses = Map.values(recordings) |> Enum.map(& &1.status)

    %{
      total: length(statuses),
      recorded: Enum.count(statuses, &(&1 in [:recorded, :already_recorded])),
      failed: Enum.count(statuses, &(&1 == :failed)),
      waiting: Enum.count(statuses, &(&1 in [:queued, :retrying]))
    }
  end

  def recording_badge(:queued), do: {"bg-admin-sunken text-admin-ink-faint", "Queued"}
  def recording_badge(:retrying), do: {"bg-caution-surface text-caution-strong", "Retrying"}
  def recording_badge(:recorded), do: {"bg-positive-surface text-positive-strong", "Recorded"}

  def recording_badge(:already_recorded),
    do: {"bg-positive-surface text-positive-strong", "Already recorded"}

  def recording_badge(:failed), do: {"bg-danger-surface text-danger-strong", "Failed"}

  def status_badge(:pending), do: {"bg-admin-sunken text-admin-ink-faint", "Waiting"}
  def status_badge({:working, _}), do: {"bg-navy/10 text-navy animate-pulse", "Creating"}
  def status_badge({:audio, _}), do: {"bg-notice-surface text-notice animate-pulse", "Queueing"}
  def status_badge({:ok, _}), do: {"bg-positive-surface text-positive-strong", "Done"}
  def status_badge({:warning, _}), do: {"bg-caution-surface text-caution-strong", "Partial"}
  def status_badge({:error, _}), do: {"bg-danger-surface text-danger-strong", "Failed"}

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted. Please upload a CSV file"

  defp error_to_string(:too_many_files),
    do: "Too many files selected. Please upload only one CSV file"
end
