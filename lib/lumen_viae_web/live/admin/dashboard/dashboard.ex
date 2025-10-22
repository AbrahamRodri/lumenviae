defmodule LumenViaeWeb.Live.Admin.Dashboard do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin - Manage Content")
     |> assign(:meditation_sets, Rosary.list_meditation_sets())
     |> assign(:meditations, Rosary.list_meditations())
     |> assign(:mysteries, Rosary.list_mysteries())
     |> assign(:selected_set, nil)
     |> assign(:selected_set_meditations, [])
     |> assign(:filter_category, nil)
     |> assign(:saved_author, "")
     |> assign(:saved_source, "")
     |> assign(:remember_author, false)
     |> assign(:remember_source, false)
     |> assign(:expanded_meditation_id, nil)
     |> assign(:editing_meditation_id, nil)
     |> assign(:edit_form, nil)
     |> assign_meditation_form()
     |> assign_meditation_set_form()}
  end

  defp assign_meditation_form(socket) do
    author = if socket.assigns.remember_author, do: socket.assigns.saved_author, else: ""
    source = if socket.assigns.remember_source, do: socket.assigns.saved_source, else: ""
    assign(socket, :meditation_form, to_form(%{"mystery_id" => "", "title" => "", "content" => "", "author" => author, "source" => source}))
  end

  defp assign_meditation_set_form(socket) do
    assign(socket, :meditation_set_form, to_form(%{"name" => "", "category" => "", "description" => ""}))
  end

  defp filtered_mysteries(assigns) do
    case assigns.filter_category do
      nil -> assigns.mysteries
      category -> Enum.filter(assigns.mysteries, fn m -> m.category == category end)
    end
  end

  def handle_event("create_meditation", params, socket) do
    # Get current remember states
    remember_author = socket.assigns.remember_author
    remember_source = socket.assigns.remember_source

    # Save author and source if remember checkboxes are checked
    saved_author = if remember_author, do: params["author"] || "", else: ""
    saved_source = if remember_source, do: params["source"] || "", else: ""

    case Rosary.create_meditation(params) do
      {:ok, _meditation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation created successfully")
         |> assign(:meditations, Rosary.list_meditations())
         |> assign(:saved_author, saved_author)
         |> assign(:saved_source, saved_source)
         |> assign_meditation_form()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create meditation")}
    end
  end

  def handle_event("toggle_remember_author", _params, socket) do
    remember = !socket.assigns.remember_author
    {:noreply, assign(socket, :remember_author, remember)}
  end

  def handle_event("toggle_remember_source", _params, socket) do
    remember = !socket.assigns.remember_source
    {:noreply, assign(socket, :remember_source, remember)}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    filter = if category == "", do: nil, else: category
    {:noreply, assign(socket, :filter_category, filter)}
  end

  def handle_event("toggle_meditation", %{"id" => id}, socket) do
    meditation_id = String.to_integer(id)
    expanded_id = if socket.assigns.expanded_meditation_id == meditation_id, do: nil, else: meditation_id
    {:noreply, assign(socket, :expanded_meditation_id, expanded_id)}
  end

  def handle_event("edit_meditation", %{"id" => id}, socket) do
    meditation_id = String.to_integer(id)
    meditation = Rosary.get_meditation!(meditation_id)

    edit_form = to_form(%{
      "mystery_id" => to_string(meditation.mystery_id),
      "title" => meditation.title || "",
      "content" => meditation.content,
      "author" => meditation.author || "",
      "source" => meditation.source || ""
    })

    {:noreply,
     socket
     |> assign(:editing_meditation_id, meditation_id)
     |> assign(:edit_form, edit_form)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_meditation_id, nil)
     |> assign(:edit_form, nil)}
  end

  def handle_event("update_meditation", %{"meditation_id" => id} = params, socket) do
    meditation_id = String.to_integer(id)
    meditation = Rosary.get_meditation!(meditation_id)

    case Rosary.update_meditation(meditation, params) do
      {:ok, _meditation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation updated successfully")
         |> assign(:meditations, Rosary.list_meditations())
         |> assign(:editing_meditation_id, nil)
         |> assign(:edit_form, nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update meditation")}
    end
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

  def handle_event("create_meditation_set", params, socket) do
    case Rosary.create_meditation_set(params) do
      {:ok, _set} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation set created successfully")
         |> assign(:meditation_sets, Rosary.list_meditation_sets())
         |> assign_meditation_set_form()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create meditation set")}
    end
  end

  def handle_event("select_set", %{"set_id" => set_id}, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

    {:noreply,
     socket
     |> assign(:selected_set, set)
     |> assign(:selected_set_meditations, set.meditations)}
  end

  def handle_event("add_to_set", %{"meditation_id" => meditation_id, "order" => order}, socket) do
    set_id = socket.assigns.selected_set.id

    case Rosary.add_meditation_to_set(set_id, String.to_integer(meditation_id), String.to_integer(order)) do
      {:ok, _} ->
        set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

        {:noreply,
         socket
         |> put_flash(:info, "Meditation added to set")
         |> assign(:selected_set, set)
         |> assign(:selected_set_meditations, set.meditations)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add meditation to set")}
    end
  end

  def handle_event("remove_from_set", %{"meditation_id" => meditation_id}, socket) do
    set_id = socket.assigns.selected_set.id
    Rosary.remove_meditation_from_set(set_id, String.to_integer(meditation_id))
    set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

    {:noreply,
     socket
     |> put_flash(:info, "Meditation removed from set")
     |> assign(:selected_set, set)
     |> assign(:selected_set_meditations, set.meditations)}
  end

end
