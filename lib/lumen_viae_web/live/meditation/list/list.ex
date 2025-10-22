defmodule LumenViaeWeb.Live.Meditation.List do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Meditations")
     |> assign(:meditations, Rosary.list_meditations())
     |> assign(:expanded_meditation_id, nil)
     |> assign(:filter_category, nil)}
  end

  def handle_event("toggle_meditation", %{"id" => id}, socket) do
    meditation_id = String.to_integer(id)

    expanded_id =
      if socket.assigns.expanded_meditation_id == meditation_id, do: nil, else: meditation_id

    {:noreply, assign(socket, :expanded_meditation_id, expanded_id)}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    filter = if category == "", do: nil, else: category
    {:noreply, assign(socket, :filter_category, filter)}
  end

  def handle_event("delete_meditation", %{"id" => id}, socket) do
    meditation_id = String.to_integer(id)
    meditation = Rosary.get_meditation!(meditation_id)

    case Rosary.delete_meditation(meditation) do
      {:ok, _meditation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation deleted successfully")
         |> assign(:meditations, Rosary.list_meditations())
         |> assign(:expanded_meditation_id, nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete meditation")}
    end
  end

  defp filtered_meditations(assigns) do
    case assigns.filter_category do
      nil ->
        assigns.meditations

      category ->
        Enum.filter(assigns.meditations, fn m ->
          m.mystery.category == category
        end)
    end
  end
end
