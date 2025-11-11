defmodule LumenViaeWeb.Live.Meditations.Sets.Edit do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(%{"id" => id}, _session, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(id)
    meditations = Rosary.list_meditations()

    {:ok,
     socket
     |> assign(:page_title, "Edit Meditation Set")
     |> assign(:meditation_set, set)
     |> assign(:meditations, meditations)
     |> assign(:available_authors, available_authors(meditations))
     |> assign(:filter_category, nil)
     |> assign(:filter_author, nil)
     |> assign(:search_query, "")
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

  def handle_event("update_filters", params, socket) do
    {:noreply,
     socket
     |> assign(:filter_category, blank_to_nil(params["category"]))
     |> assign(:filter_author, blank_to_nil(params["author"]))
     |> assign(:search_query, String.trim(params["query"] || ""))}
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

  defp available_authors(meditations) do
    meditations
    |> Enum.map(&(&1.author || ""))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp filtered_meditations(assigns) do
    assigns.meditations
    |> filter_by_category(assigns.filter_category)
    |> filter_by_author(assigns.filter_author)
    |> filter_by_query(assigns.search_query)
  end

  defp filter_by_category(meditations, nil), do: meditations

  defp filter_by_category(meditations, category) do
    Enum.filter(meditations, fn meditation -> meditation.mystery.category == category end)
  end

  defp filter_by_author(meditations, nil), do: meditations

  defp filter_by_author(meditations, author) do
    Enum.filter(meditations, fn meditation -> meditation.author == author end)
  end

  defp filter_by_query(meditations, ""), do: meditations

  defp filter_by_query(meditations, query) do
    downcased_query = String.downcase(query)

    Enum.filter(meditations, fn meditation ->
      matches?(meditation.title, downcased_query) ||
        matches?(meditation.author, downcased_query) ||
        matches?(meditation.mystery.name, downcased_query)
    end)
  end

  defp matches?(nil, _query), do: false

  defp matches?(value, query) do
    value
    |> String.downcase()
    |> String.contains?(query)
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
