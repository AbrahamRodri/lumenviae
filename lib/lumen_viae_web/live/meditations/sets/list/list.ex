defmodule LumenViaeWeb.Live.Meditations.Sets.List do
  use LumenViaeWeb, :live_view
  import LumenViaeWeb.Live.Meditations.Sets.List.SetRow
  alias LumenViae.Rosary.Categories
  alias LumenViaeWeb.Live.Meditations.Sets.Filtering, as: SetFiltering
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Labels

  @sort_options ~w(category name newest meditations)
  @default_sort "category"

  # The list answers "what is the public being served?" unless asked
  # otherwise, so visibility starts at "visible" rather than at "everything".
  @default_visibility "visible"
  @visibility_options ~w(visible hidden all)

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Meditation Sets")
     |> assign(:mystery_categories, Categories.options())
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

  # The summary counts live sets only, apart from the hidden tally itself:
  # an incomplete set that nobody can reach is not the same problem as an
  # incomplete set on the shelf, and mixing them makes the number useless.
  defp summarize(sets, hidden_ids, stats) do
    {hidden, live} = Enum.split_with(sets, &MapSet.member?(hidden_ids, &1.id))

    %{
      total: length(sets),
      live: length(live),
      hidden: length(hidden),
      empty: Enum.count(live, &(SetFiltering.meditation_count(&1, stats) == 0)),
      incomplete:
        Enum.count(live, fn set ->
          SetFiltering.meditation_count(set, stats) !=
            Rosary.expected_meditation_count(set.category)
        end),
      no_artwork: Enum.count(live, &(SetFiltering.artwork_state(&1) == :missing)),
      no_labels: Enum.count(live, &(&1.labels == []))
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
          completeness: filters.completeness,
          artwork: filters.artwork
        },
        %{hidden_ids: socket.assigns.hidden_set_ids, stats: stats}
      )
      |> SetFiltering.sort_sets(filters.sort, stats)

    assign(socket, :filtered_sets, filtered)
  end

  defp parse_filters(params) do
    %{
      query: String.trim(params["q"] || ""),
      category: allowed(params["category"], Categories.slugs()),
      label: allowed(params["label"], ["none" | Labels.vocabulary()]),
      visibility: allowed(params["visibility"], @visibility_options) || @default_visibility,
      completeness: allowed(params["completeness"], ~w(complete incomplete empty)),
      artwork: allowed(params["artwork"], ~w(missing unpublishable served)),
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
      artwork: params["artwork"],
      sort: params["sort"]
    ]
    |> Enum.reject(fn {key, value} ->
      value in [nil, ""] or (key == :sort and value == @default_sort) or
        (key == :visibility and value == @default_visibility)
    end)
  end

  defp allowed(value, options) do
    if value in options, do: value
  end

  def filters_applied?(filters) do
    filters.query != "" or filters.category != nil or filters.label != nil or
      filters.visibility != @default_visibility or filters.completeness != nil or
      filters.artwork != nil or filters.sort != @default_sort
  end
end
