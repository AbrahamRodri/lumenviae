defmodule LumenViaeWeb.Live.Pray.Index do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  @impl true
  def mount(%{"set_id" => set_id}, _session, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

    if set do
      {:ok,
       socket
       |> assign(:set, set)
       |> assign(:current_index, 0)
       |> assign(:page_title, set.name)
       |> assign(:hide_site_chrome, true)
       |> assign(:prayer_started?, false)
       |> assign(:total_count, length(set.meditations))
       |> assign(:unique_mysteries, unique_mysteries(set))
       |> assign_current_meditation(0)}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("next", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)

    new_index = current + 1 |> clamp_index(total)

    {:noreply, assign_current_meditation(socket, new_index)}
  end

  def handle_event("previous", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)
    new_index = current - 1 |> clamp_index(total)

    {:noreply, assign_current_meditation(socket, new_index)}
  end

  def handle_event("restore_progress", %{"index" => index}, socket) do
    total = length(socket.assigns.set.meditations)
    # Ensure index is valid (within bounds)
    valid_index = index |> normalize_index() |> clamp_index(total)
    {:noreply,
     socket
     |> assign(:prayer_started?, true)
     |> assign_current_meditation(valid_index)}
  end

  def handle_event("start_prayer", _params, socket) do
    {:noreply, assign(socket, :prayer_started?, true)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp assign_current_meditation(socket, index) do
    meditations = socket.assigns.set.meditations
    total = length(meditations)
    safe_index = clamp_index(index, total)
    meditation = Enum.at(meditations, safe_index)

    announcement_audio_url =
      case meditation do
        %{mystery: mystery} -> Rosary.get_mystery_announcement_audio_url(mystery)
        _ -> nil
      end

    audio_presigned_url =
      case meditation do
        nil -> nil
        _ -> Rosary.get_meditation_audio_url(meditation)
      end

    socket
    |> assign(:current_index, safe_index)
    |> assign(:meditation, meditation)
    |> assign(:announcement_audio_url, announcement_audio_url)
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

  defp unique_mysteries(%{meditations: meditations}) do
    meditations
    |> Enum.map(& &1.mystery)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.id)
  end

  defp unique_mysteries(_), do: []
end
