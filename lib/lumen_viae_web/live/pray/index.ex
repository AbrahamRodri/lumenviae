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
       |> assign(:auto_play, false)
       |> assign(:hide_chrome, true)}
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
    |> assign_current_meditation(new_index)
    |> assign(:auto_play, true)
    |> then(&{:noreply, &1})
  end

  def handle_event("previous", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)
    new_index = current - 1 |> clamp_index(total)

    socket
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
