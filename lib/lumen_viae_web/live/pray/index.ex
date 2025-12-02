defmodule LumenViaeWeb.Live.Pray.Index do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  @impl true
  def mount(%{"set_id" => set_id}, _session, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

    # Capture IP address during mount (only time connect_info is available)
    ip_address = get_connect_info(socket, :peer_data) |> get_ip_address()

    case set.meditations do
      [_ | _] = meditations ->
        # Pre-generate all audio URLs once on mount instead of on every navigation
        audio_urls = Enum.map(meditations, &Rosary.get_meditation_audio_url/1)

        {:ok,
         socket
         |> assign(:set, set)
         |> assign(:audio_urls, audio_urls)
         |> assign(:current_index, 0)
         |> assign(:completion_tracked, false)
         |> assign(:ip_address, ip_address)
         |> assign(:page_title, set.name)}

      [] ->
        {:ok,
         socket
         |> put_flash(:error, "This meditation set has no meditations yet")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("next", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)

    new_index = (current + 1) |> clamp_index(total)

    socket
    |> assign_current_meditation(new_index)
    |> maybe_track_completion(new_index)
    |> then(&{:noreply, &1})
  end

  def handle_event("previous", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)
    new_index = (current - 1) |> clamp_index(total)

    socket
    |> assign_current_meditation(new_index)
    |> then(&{:noreply, &1})
  end

  def handle_event("restore_progress", %{"index" => index}, socket) do
    total = length(socket.assigns.set.meditations)
    # Ensure index is valid (within bounds)
    valid_index = index |> normalize_index() |> clamp_index(total)
    {:noreply, assign_current_meditation(socket, valid_index)}
  end

  def handle_event("audio_ended", _params, socket) do
    {:noreply, socket}
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
    audio_presigned_url = Enum.at(socket.assigns.audio_urls, index)

    socket
    |> assign(:current_index, index)
    |> assign(:meditation, meditation)
    |> assign(:audio_presigned_url, audio_presigned_url)
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

  defp maybe_track_completion(socket, new_index) do
    # Track completion when reaching the 5th mystery (index 4) for the first time
    # Only track once per session to avoid double-counting if user navigates back
    if new_index == 4 && !socket.assigns.completion_tracked do
      Rosary.record_completion(socket.assigns.set.id, socket.assigns.ip_address)
      assign(socket, :completion_tracked, true)
    else
      socket
    end
  end

  defp get_ip_address(nil), do: nil
  defp get_ip_address(%{address: address}) do
    case address do
      {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
      {a, b, c, d, e, f, g, h} ->
        # IPv6 format (simplified)
        "#{Integer.to_string(a, 16)}:#{Integer.to_string(b, 16)}:#{Integer.to_string(c, 16)}:#{Integer.to_string(d, 16)}:#{Integer.to_string(e, 16)}:#{Integer.to_string(f, 16)}:#{Integer.to_string(g, 16)}:#{Integer.to_string(h, 16)}"
      _ -> nil
    end
  end
end
