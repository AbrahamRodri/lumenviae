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
       |> assign(:page_title, set.name)}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("next", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)

    new_index = min(current + 1, total - 1)
    {:noreply, assign(socket, :current_index, new_index)}
  end

  def handle_event("previous", _params, socket) do
    current = socket.assigns.current_index
    new_index = max(current - 1, 0)
    {:noreply, assign(socket, :current_index, new_index)}
  end

  def handle_event("restore_progress", %{"index" => index}, socket) do
    total = length(socket.assigns.set.meditations)
    # Ensure index is valid (within bounds)
    valid_index = max(0, min(index, total - 1))
    {:noreply, assign(socket, :current_index, valid_index)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    meditation = current_meditation(socket.assigns)
    total_count = length(socket.assigns.set.meditations)

    {:noreply,
     socket
     |> assign(:meditation, meditation)
     |> assign(:total_count, total_count)}
  end

  defp current_meditation(assigns) do
    Enum.at(assigns.set.meditations, assigns.current_index)
  end
end
