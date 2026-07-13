defmodule LumenViaeWeb.Live.Meditations.Sets.List do
  use LumenViaeWeb, :live_view
  import LumenViaeWeb.Live.Meditations.Sets.List.SetCard
  alias LumenViae.Constants
  alias LumenViae.Meditations.SetFiltering
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Labels

  @sort_options ~w(category name newest meditations)
  @default_sort "category"

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Meditation Sets")
     |> assign(:mystery_categories, Constants.mystery_category_options())
     |> assign(:label_vocabulary, Labels.vocabulary())
     |> assign(:expanded_set_id, nil)
     |> assign(:expanded_meditations, [])
     |> load_data()}
  end

  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:filters, parse_filters(params))
     |> apply_filters()}
  end

  def handle_event("update_filters", params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/meditation-sets?#{filter_query_params(params)}")}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/meditation-sets")}
  end

  def handle_event("toggle_expand", %{"id" => id}, socket) do
    set_id = String.to_integer(id)

    if socket.assigns.expanded_set_id == set_id do
      {:noreply, socket |> assign(:expanded_set_id, nil) |> assign(:expanded_meditations, [])}
    else
      set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

      {:noreply,
       socket
       |> assign(:expanded_set_id, set_id)
       |> assign(:expanded_meditations, set.meditations)}
    end
  end

  def handle_event("delete_set", %{"id" => id}, socket) do
    set = Rosary.get_meditation_set!(id)

    case Rosary.delete_meditation_set(set) do
      {:ok, _set} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation set deleted successfully")
         |> assign(:expanded_set_id, nil)
         |> assign(:expanded_meditations, [])
         |> load_data()
         |> apply_filters()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete meditation set")}
    end
  end

  defp load_data(socket) do
    sets = Rosary.list_meditation_sets()
    hidden_ids = Rosary.hidden_meditation_set_ids()
    stats = Rosary.meditation_set_stats()

    socket
    |> assign(:meditation_sets, sets)
    |> assign(:hidden_set_ids, hidden_ids)
    |> assign(:set_stats, stats)
    |> assign(:summary, summarize(sets, hidden_ids, stats))
  end

  defp summarize(sets, hidden_ids, stats) do
    %{
      total: length(sets),
      hidden: Enum.count(sets, &MapSet.member?(hidden_ids, &1.id)),
      empty: Enum.count(sets, &(SetFiltering.meditation_count(&1, stats) == 0)),
      incomplete:
        Enum.count(sets, fn set ->
          SetFiltering.meditation_count(set, stats) !=
            SetFiltering.expected_meditation_count(set.category)
        end)
    }
  end

  defp apply_filters(socket) do
    filters = socket.assigns.filters
    stats = socket.assigns.set_stats

    filtered =
      socket.assigns.meditation_sets
      |> SetFiltering.filter_sets(
        %{
          query: filters.query,
          category: filters.category,
          label: filters.label,
          visibility: filters.visibility,
          completeness: filters.completeness
        },
        %{hidden_ids: socket.assigns.hidden_set_ids, stats: stats}
      )
      |> SetFiltering.sort_sets(filters.sort, stats)

    assign(socket, :filtered_sets, filtered)
  end

  defp parse_filters(params) do
    %{
      query: String.trim(params["q"] || ""),
      category: allowed(params["category"], ~w(joyful sorrowful glorious seven_sorrows)),
      label: allowed(params["label"], Labels.vocabulary()),
      visibility: allowed(params["visibility"], ~w(visible hidden)),
      completeness: allowed(params["completeness"], ~w(complete incomplete empty)),
      sort: allowed(params["sort"], @sort_options) || @default_sort
    }
  end

  defp filter_query_params(params) do
    [
      q: String.trim(params["q"] || ""),
      category: params["category"],
      label: params["label"],
      visibility: params["visibility"],
      completeness: params["completeness"],
      sort: params["sort"]
    ]
    |> Enum.reject(fn {key, value} ->
      value in [nil, ""] or (key == :sort and value == @default_sort)
    end)
  end

  defp allowed(value, options) do
    if value in options, do: value
  end

  def filters_applied?(filters) do
    filters.query != "" or filters.category != nil or filters.label != nil or
      filters.visibility != nil or filters.completeness != nil or
      filters.sort != @default_sort
  end
end
