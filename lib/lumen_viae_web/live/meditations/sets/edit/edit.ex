defmodule LumenViaeWeb.Live.Meditations.Sets.Edit do
  use LumenViaeWeb, :live_view
  import LumenViaeWeb.Live.Meditations.Helpers
  alias LumenViae.Constants
  alias LumenViae.Meditations.Filtering
  alias LumenViae.Rosary
  alias LumenViae.Rosary.MeditationSet

  def mount(%{"id" => id}, _session, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(id)
    meditations = Rosary.list_meditations()

    {:ok,
     socket
     |> assign(:page_title, "Edit Meditation Set")
     |> assign(:meditation_set, set)
     |> assign(:meditations, meditations)
     |> assign(:available_authors, Filtering.available_authors(meditations))
     |> assign(:filter_category, nil)
     |> assign(:filter_author, nil)
     |> assign(:search_query, "")
     |> assign(:selected_set_meditations, set.meditations)
     |> assign(:mystery_categories, Constants.mystery_category_options())
     |> assign_edit_form(set)}
  end

  def handle_event("update_meditation_set", %{"meditation_set" => params}, socket) do
    case Rosary.update_meditation_set(socket.assigns.meditation_set, params) do
      {:ok, set} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation set updated successfully")
         |> assign(:meditation_set, set)
         |> assign_edit_form(set)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update meditation set")
         |> assign_edit_form(changeset)}
    end
  end

  def handle_event("add_to_set", %{"meditation_id" => meditation_id, "order" => order}, socket) do
    set_id = socket.assigns.meditation_set.id

    with {meditation_id_int, ""} <- Integer.parse(meditation_id),
         {order_int, ""} <- Integer.parse(order),
         true <- order_int >= 1 and order_int <= 7 do
      case Rosary.add_meditation_to_set(set_id, meditation_id_int, order_int) do
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
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid meditation ID or order (must be 1-7)")}
    end
  end

  def handle_event("update_filters", params, socket) do
    {:noreply,
     socket
     |> assign(:filter_category, Filtering.blank_to_nil(params["category"]))
     |> assign(:filter_author, Filtering.blank_to_nil(params["author"]))
     |> assign(:search_query, String.trim(params["query"] || ""))}
  end

  def handle_event("remove_from_set", %{"meditation_id" => meditation_id}, socket) do
    set_id = socket.assigns.meditation_set.id

    case Integer.parse(meditation_id) do
      {meditation_id_int, ""} ->
        Rosary.remove_meditation_from_set(set_id, meditation_id_int)
        set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

        {:noreply,
         socket
         |> put_flash(:info, "Meditation removed from set")
         |> assign(:meditation_set, set)
         |> assign(:selected_set_meditations, set.meditations)}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid meditation ID")}
    end
  end

  defp assign_edit_form(socket, %MeditationSet{} = set) do
    assign_edit_form(socket, Rosary.change_meditation_set(set))
  end

  defp assign_edit_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :edit_form, to_form(changeset, as: :meditation_set))
  end
end
