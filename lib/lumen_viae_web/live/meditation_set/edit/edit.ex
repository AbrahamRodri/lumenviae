defmodule LumenViaeWeb.Live.MeditationSet.Edit do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(%{"id" => id}, _session, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(id)

    {:ok,
     socket
     |> assign(:page_title, "Edit Meditation Set")
     |> assign(:meditation_set, set)
     |> assign(:meditations, Rosary.list_meditations())
     |> assign(:selected_set_meditations, set.meditations)
     |> assign_edit_form(set)}
  end

  def handle_event("update_meditation_set", params, socket) do
    case Rosary.update_meditation_set(socket.assigns.meditation_set, params) do
      {:ok, set} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation set updated successfully")
         |> assign(:meditation_set, set)
         |> assign_edit_form(set)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update meditation set")}
    end
  end

  def handle_event("add_to_set", %{"meditation_id" => meditation_id, "order" => order}, socket) do
    set_id = socket.assigns.meditation_set.id

    case Rosary.add_meditation_to_set(
           set_id,
           String.to_integer(meditation_id),
           String.to_integer(order)
         ) do
      {:ok, _} ->
        set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

        {:noreply,
         socket
         |> put_flash(:info, "Meditation added to set")
         |> assign(:meditation_set, set)
         |> assign(:selected_set_meditations, set.meditations)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add meditation to set")}
    end
  end

  def handle_event("remove_from_set", %{"meditation_id" => meditation_id}, socket) do
    set_id = socket.assigns.meditation_set.id
    Rosary.remove_meditation_from_set(set_id, String.to_integer(meditation_id))
    set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

    {:noreply,
     socket
     |> put_flash(:info, "Meditation removed from set")
     |> assign(:meditation_set, set)
     |> assign(:selected_set_meditations, set.meditations)}
  end

  defp assign_edit_form(socket, set) do
    assign(
      socket,
      :edit_form,
      to_form(%{
        "name" => set.name,
        "category" => set.category,
        "description" => set.description || ""
      })
    )
  end
end
