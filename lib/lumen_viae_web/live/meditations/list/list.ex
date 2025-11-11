defmodule LumenViaeWeb.Live.Meditations.List do
  use LumenViaeWeb, :live_view
  alias LumenViae.Meditations.Filtering
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    meditations = Rosary.list_meditations()

    {:ok,
     socket
     |> assign(:page_title, "Meditations")
     |> assign(:meditations, meditations)
     |> assign(:expanded_meditation_id, nil)
     |> assign(:filter_category, nil)
     |> assign(:filter_author, nil)
     |> assign(:search_query, "")
     |> assign(:available_authors, Filtering.available_authors(meditations))}
  end

  def handle_event("toggle_meditation", %{"id" => id}, socket) do
    meditation_id = String.to_integer(id)

    expanded_id =
      if socket.assigns.expanded_meditation_id == meditation_id, do: nil, else: meditation_id

    {:noreply, assign(socket, :expanded_meditation_id, expanded_id)}
  end

  def handle_event("update_filters", params, socket) do
    {:noreply,
     socket
     |> assign(:filter_category, Filtering.blank_to_nil(params["category"]))
     |> assign(:filter_author, Filtering.blank_to_nil(params["author"]))
     |> assign(:search_query, String.trim(params["query"] || ""))}
  end

  def handle_event("delete_meditation", %{"id" => id}, socket) do
    meditation_id = String.to_integer(id)
    meditation = Rosary.get_meditation!(meditation_id)

    case Rosary.delete_meditation(meditation) do
      {:ok, _meditation} ->
        meditations = Rosary.list_meditations()

        {:noreply,
         socket
         |> put_flash(:info, "Meditation deleted successfully")
         |> assign(:meditations, meditations)
         |> assign(:available_authors, Filtering.available_authors(meditations))
         |> assign(:expanded_meditation_id, nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete meditation")}
    end
  end

  defp filtered_meditations(assigns) do
    Filtering.filter_meditations(assigns.meditations, %{
      category: assigns.filter_category,
      author: assigns.filter_author,
      query: assigns.search_query
    })
  end
end
