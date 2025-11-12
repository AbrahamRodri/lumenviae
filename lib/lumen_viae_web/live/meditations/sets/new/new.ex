defmodule LumenViaeWeb.Live.Meditations.Sets.New do
  use LumenViaeWeb, :live_view
  import LumenViaeWeb.Live.Meditations.Helpers
  alias LumenViae.Constants
  alias LumenViae.Meditations.Filtering
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    meditations = Rosary.list_meditations()

    {:ok,
     socket
     |> assign(:page_title, "Create Meditation Set")
     |> assign(:meditations, meditations)
     |> assign(:filter_category, nil)
     |> assign(:filter_author, nil)
     |> assign(:search_query, "")
     |> assign(:available_authors, Filtering.available_authors(meditations))
     |> assign(:mystery_categories, Constants.mystery_category_options())
     |> assign_meditation_set_form()}
  end

  def handle_event("create_meditation_set", params, socket) do
    case Rosary.create_meditation_set(params) do
      {:ok, set} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation set created successfully")
         |> push_navigate(to: "/admin/meditation-sets/#{set.id}/edit")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create meditation set")}
    end
  end

  def handle_event("update_filters", params, socket) do
    {:noreply,
     socket
     |> assign(:filter_category, Filtering.blank_to_nil(params["category"]))
     |> assign(:filter_author, Filtering.blank_to_nil(params["author"]))
     |> assign(:search_query, String.trim(params["query"] || ""))}
  end

  defp assign_meditation_set_form(socket) do
    assign(
      socket,
      :meditation_set_form,
      to_form(%{"name" => "", "category" => "", "description" => ""})
    )
  end

  defp content_snippet(nil), do: ""

  defp content_snippet(content) do
    trimmed =
      content
      |> String.trim()
      |> String.replace(~r/\s+/, " ")

    snippet = String.slice(trimmed, 0, 160) || ""

    if String.length(snippet) < String.length(trimmed) do
      snippet <> "…"
    else
      snippet
    end
  end
end
