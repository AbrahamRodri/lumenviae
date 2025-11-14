defmodule LumenViaeWeb.Live.Mysteries.List do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    mysteries = Rosary.list_mysteries()

    {:ok,
     socket
     |> assign(:page_title, "Mysteries")
     |> assign(:mysteries, mysteries)
     |> assign(:expanded_mystery_id, nil)}
  end

  def handle_event("toggle_mystery", %{"id" => id}, socket) do
    mystery_id = String.to_integer(id)

    expanded_id =
      if socket.assigns.expanded_mystery_id == mystery_id, do: nil, else: mystery_id

    {:noreply, assign(socket, :expanded_mystery_id, expanded_id)}
  end
end
