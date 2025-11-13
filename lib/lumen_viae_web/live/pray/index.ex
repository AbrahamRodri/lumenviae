defmodule LumenViaeWeb.Live.Pray.Index do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  # 5 minutes in milliseconds for automatic mode interval
  @automatic_interval 300_000

  @impl true
  def mount(%{"set_id" => set_id}, _session, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

    if set do
      {:ok,
       socket
       |> assign(:set, set)
       |> assign(:current_index, 0)
       |> assign(:page_title, set.name)
       |> assign(:prayer_mode, "manual")
       |> assign(:timer_ref, nil)
       |> assign(:auto_play, false)}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("next", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)

    new_index = current + 1 |> clamp_index(total)

    socket
    |> cancel_timer()
    |> assign_current_meditation(new_index)
    |> assign(:auto_play, true)
    |> then(&{:noreply, &1})
  end

  def handle_event("previous", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)
    new_index = current - 1 |> clamp_index(total)

    socket
    |> cancel_timer()
    |> assign_current_meditation(new_index)
    |> assign(:auto_play, true)
    |> then(&{:noreply, &1})
  end

  def handle_event("restore_progress", %{"index" => index}, socket) do
    total = length(socket.assigns.set.meditations)
    # Ensure index is valid (within bounds)
    valid_index = index |> normalize_index() |> clamp_index(total)
    {:noreply, assign_current_meditation(socket, valid_index)}
  end

  def handle_event("audio_ended", _params, socket) do
    # Only advance automatically if in automatic mode
    if socket.assigns.prayer_mode == "automatic" do
      # Start 5-minute timer before advancing
      timer_ref = Process.send_after(self(), :advance_meditation, @automatic_interval)

      {:noreply, assign(socket, :timer_ref, timer_ref)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_prayer_mode", %{"mode" => mode}, socket) do
    socket
    |> cancel_timer()
    |> assign(:prayer_mode, mode)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info(:advance_meditation, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)
    new_index = current + 1 |> clamp_index(total)

    # Only advance if not at the last meditation
    if new_index > current do
      socket
      |> assign_current_meditation(new_index)
      |> assign(:auto_play, true)
      |> assign(:timer_ref, nil)
      |> then(&{:noreply, &1})
    else
      # At the last meditation - stop automatic mode
      {:noreply, assign(socket, :timer_ref, nil)}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    cancel_timer(socket)
    :ok
  end

  @impl true
  def handle_params(_params, _url, socket) do
    total_count = length(socket.assigns.set.meditations)

    {:noreply,
     socket
     |> assign(:total_count, total_count)
     |> assign_current_meditation(socket.assigns.current_index)}
  end

  defp assign_current_meditation(socket, index) do
    meditation = Enum.at(socket.assigns.set.meditations, index)
    audio_presigned_url = Rosary.get_meditation_audio_url(meditation)

    socket
    |> assign(:current_index, index)
    |> assign(:meditation, meditation)
    |> assign(:audio_presigned_url, audio_presigned_url)
  end

  defp cancel_timer(socket) do
    if socket.assigns.timer_ref do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    assign(socket, :timer_ref, nil)
  end

  defp clamp_index(_index, total) when total <= 0, do: 0

  defp clamp_index(index, total) do
    index
    |> max(0)
    |> min(total - 1)
  end

  defp normalize_index(index) when is_integer(index), do: index

  defp normalize_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {value, _} -> value
      :error -> 0
    end
  end

  defp normalize_index(_), do: 0
end
