defmodule LumenViaeWeb.Live.Pray.Index do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  @impl true
  def mount(%{"set_id" => set_id}, _session, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

    # TODO: IP-based geolocation tracking is disabled for now
    # To enable: uncomment the code below and in maybe_track_completion
    # ip_address = get_connect_info(socket, :peer_data) |> get_ip_address()

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
         |> assign(:mobile_mode_enabled, false)
         |> assign(:mobile_mode_preference, "auto")
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

  def handle_event("toggle_mobile_mode", %{"preference" => preference}, socket) do
    enabled =
      case preference do
        "on" -> true
        "off" -> false
        "auto" -> socket.assigns.mobile_mode_enabled
      end

    {:noreply,
     socket
     |> assign(:mobile_mode_enabled, enabled)
     |> assign(:mobile_mode_preference, preference)}
  end

  def handle_event("init_mobile_mode", %{"enabled" => enabled, "preference" => preference}, socket) do
    {:noreply,
     socket
     |> assign(:mobile_mode_enabled, enabled)
     |> assign(:mobile_mode_preference, preference)}
  end

  def handle_event("update_mobile_mode_auto", %{"enabled" => enabled}, socket) do
    if socket.assigns.mobile_mode_preference == "auto" do
      {:noreply, assign(socket, :mobile_mode_enabled, enabled)}
    else
      {:noreply, socket}
    end
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
      # TODO: IP tracking disabled - passing nil for now
      # To enable: pass socket.assigns.ip_address instead of nil
      Rosary.record_completion(socket.assigns.set.id, nil)
      assign(socket, :completion_tracked, true)
    else
      socket
    end
  end

  # TODO: Archived IP address extraction functions for future use
  # Uncomment when re-enabling IP tracking
  # defp get_ip_address(nil), do: nil
  # defp get_ip_address(%{address: address}) do
  #   case address do
  #     {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
  #     {a, b, c, d, e, f, g, h} ->
  #       # IPv6 format (simplified)
  #       "#{Integer.to_string(a, 16)}:#{Integer.to_string(b, 16)}:#{Integer.to_string(c, 16)}:#{Integer.to_string(d, 16)}:#{Integer.to_string(e, 16)}:#{Integer.to_string(f, 16)}:#{Integer.to_string(g, 16)}:#{Integer.to_string(h, 16)}"
  #     _ -> nil
  #   end
  # end

  defp cycle_preference("auto"), do: "on"
  defp cycle_preference("on"), do: "off"
  defp cycle_preference("off"), do: "auto"

  defp mobile_mode_title("auto"), do: "Mobile Mode: Auto"
  defp mobile_mode_title("on"), do: "Mobile Mode: On"
  defp mobile_mode_title("off"), do: "Mobile Mode: Off"

  defp mobile_mode_icon(assigns) do
    ~H"""
    <%= case @preference do %>
      <% "on" -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
          <path d="M10.5 18.75a.75.75 0 000 1.5h3a.75.75 0 000-1.5h-3z" />
          <path fill-rule="evenodd" d="M8.625.75A3.375 3.375 0 005.25 4.125v15.75a3.375 3.375 0 003.375 3.375h6.75a3.375 3.375 0 003.375-3.375V4.125A3.375 3.375 0 0015.375.75h-6.75zM7.5 4.125C7.5 3.504 8.004 3 8.625 3H9.75v.375c0 .621.504 1.125 1.125 1.125h2.25c.621 0 1.125-.504 1.125-1.125V3h1.125c.621 0 1.125.504 1.125 1.125v15.75c0 .621-.504 1.125-1.125 1.125h-6.75A1.125 1.125 0 017.5 19.875V4.125z" clip-rule="evenodd" />
        </svg>
      <% "off" -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
          <path d="M10.5 18.75a.75.75 0 000 1.5h3a.75.75 0 000-1.5h-3z" />
          <path fill-rule="evenodd" d="M2.25 2.25l19.5 19.5-1.06 1.06L17.56 19.75H15.375a3.375 3.375 0 01-3.375-3.375v-5.25L4.31 3.44 2.25 2.25zm6.375 1.875A3.375 3.375 0 015.25 7.5v12.375a3.375 3.375 0 003.375 3.375h6.75c.73 0 1.397-.232 1.947-.627l-1.572-1.573H8.625A1.125 1.125 0 017.5 19.875V7.5c0-.621.504-1.125 1.125-1.125h6.75c.621 0 1.125.504 1.125 1.125v8.625l2.25 2.25V4.125A3.375 3.375 0 0015.375.75h-6.75z" clip-rule="evenodd" />
        </svg>
      <% _ -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
          <g>
            <path d="M10.5 18.75a.75.75 0 000 1.5h3a.75.75 0 000-1.5h-3z" />
            <path fill-rule="evenodd" d="M8.625.75A3.375 3.375 0 005.25 4.125v15.75a3.375 3.375 0 003.375 3.375h6.75a3.375 3.375 0 003.375-3.375V4.125A3.375 3.375 0 0015.375.75h-6.75zM7.5 4.125C7.5 3.504 8.004 3 8.625 3H9.75v.375c0 .621.504 1.125 1.125 1.125h2.25c.621 0 1.125-.504 1.125-1.125V3h1.125c.621 0 1.125.504 1.125 1.125v15.75c0 .621-.504 1.125-1.125 1.125h-6.75A1.125 1.125 0 017.5 19.875V4.125z" clip-rule="evenodd" />
            <circle cx="18" cy="6" r="4" fill="currentColor" />
            <text x="18" y="8" font-size="6" fill="#1a1a2e" text-anchor="middle" font-weight="bold">A</text>
          </g>
        </svg>
    <% end %>
    """
  end
end
