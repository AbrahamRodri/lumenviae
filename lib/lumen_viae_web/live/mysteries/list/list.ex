defmodule LumenViaeWeb.Live.Mysteries.List do
  use LumenViaeWeb, :live_view
  alias LumenViae.Constants
  alias LumenViae.Rosary

  @categories ~w(joyful sorrowful glorious seven_sorrows)

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Mysteries")
     |> assign(:mystery_categories, Constants.mystery_category_options())
     |> load_data()}
  end

  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:filters, parse_filters(params))
     |> apply_filters()}
  end

  def handle_event("update_filters", params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/mysteries?#{filter_query_params(params)}")}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/mysteries")}
  end

  def handle_event("delete_mystery", %{"id" => id}, socket) do
    mystery = Rosary.get_mystery!(String.to_integer(id))

    case Rosary.delete_mystery(mystery) do
      {:ok, _mystery} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mystery deleted successfully")
         |> load_data()
         |> apply_filters()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete mystery")}
    end
  end

  defp load_data(socket) do
    socket
    |> assign(:mysteries, Rosary.list_mysteries())
    |> assign(:meditation_counts, Rosary.meditation_counts_by_mystery())
  end

  defp apply_filters(socket) do
    filters = socket.assigns.filters

    filtered =
      socket.assigns.mysteries
      |> filter_by_category(filters.category)
      |> filter_by_query(filters.query)

    grouped =
      @categories
      |> Enum.map(fn category ->
        {category, Enum.filter(filtered, &(&1.category == category))}
      end)
      |> Enum.reject(fn {_category, mysteries} -> mysteries == [] end)

    socket
    |> assign(:filtered_count, length(filtered))
    |> assign(:grouped_mysteries, grouped)
  end

  defp filter_by_category(mysteries, nil), do: mysteries

  defp filter_by_category(mysteries, category) do
    Enum.filter(mysteries, &(&1.category == category))
  end

  defp filter_by_query(mysteries, ""), do: mysteries

  defp filter_by_query(mysteries, query) do
    downcased_query = String.downcase(query)

    Enum.filter(mysteries, fn mystery ->
      matches?(mystery.name, downcased_query) ||
        matches?(mystery.description, downcased_query) ||
        matches?(mystery.scripture_reference, downcased_query)
    end)
  end

  defp matches?(nil, _query), do: false
  defp matches?(value, query), do: String.contains?(String.downcase(value), query)

  defp parse_filters(params) do
    %{
      query: String.trim(params["q"] || ""),
      category: if(params["category"] in @categories, do: params["category"])
    }
  end

  defp filter_query_params(params) do
    [q: String.trim(params["q"] || ""), category: params["category"]]
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
  end

  def meditation_count(counts, mystery_id), do: Map.get(counts, mystery_id, 0)
end
