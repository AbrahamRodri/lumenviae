defmodule LumenViaeWeb.Live.Meditations.Sets.New do
  use LumenViaeWeb, :live_view
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
     |> assign(:available_authors, available_authors(meditations))
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
     |> assign(:filter_category, blank_to_nil(params["category"]))
     |> assign(:filter_author, blank_to_nil(params["author"]))
     |> assign(:search_query, String.trim(params["query"] || ""))}
  end

  defp assign_meditation_set_form(socket) do
    assign(
      socket,
      :meditation_set_form,
      to_form(%{"name" => "", "category" => "", "description" => ""})
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

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
