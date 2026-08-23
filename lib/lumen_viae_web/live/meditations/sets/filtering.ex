defmodule LumenViaeWeb.Live.Meditations.Sets.Filtering do
  @moduledoc """
  In-memory filtering and sorting for the admin meditation sets list.

  Like `LumenViaeWeb.Live.Meditations.Filtering`, this narrows an
  already-fetched list rather than querying. The visibility, completeness
  and artwork filters need facts the sets themselves do not carry, so they
  are passed in as `context`.

  All filter keys are optional; a nil (or absent) value leaves the list
  untouched.

  Supported filter keys:

    * `:category` - set category string ("joyful", "sorrowful", ...)
    * `:label` - sets carrying this exact label, or "none" for sets carrying
      no label at all (which the app files under "More" in its picker)
    * `:visibility` - "visible", "hidden", or "all" (requires the MapSet of
      hidden set ids from `LumenViae.Rosary.hidden_meditation_set_ids/0`).
      The list defaults to "visible": the admin's normal question is about
      what the public is being served, and a set pulled out of circulation
      by an archived meditation is noise in the answer.
    * `:completeness` - "complete", "incomplete" (wrong meditation count for
      the category), or "empty" (requires the stats map from
      `LumenViae.Rosary.meditation_set_stats/0`)
    * `:artwork` - "missing" (no painting and no author portrait to fall
      back on), "unpublishable" (a painting that is not being served for
      want of a description or a licence), or "served"
    * `:query` - case-insensitive match against name, description, and labels
  """

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Categories

  def filter_sets(sets, filters, context \\ %{}) do
    hidden_ids = Map.get(context, :hidden_ids, MapSet.new())
    stats = Map.get(context, :stats, %{})

    sets
    |> filter_by_category(filters[:category])
    |> filter_by_label(filters[:label])
    |> filter_by_visibility(filters[:visibility], hidden_ids)
    |> filter_by_completeness(filters[:completeness], stats)
    |> filter_by_artwork(filters[:artwork])
    |> filter_by_query(filters[:query])
  end

  @doc """
  Sorts sets. Supported orders: "category" (category, then id), "name",
  "newest", "meditations" (highest count first; needs the stats map).
  Unknown values fall back to "category".
  """
  def sort_sets(sets, sort, stats \\ %{}) do
    case sort do
      "name" ->
        Enum.sort_by(sets, &{String.downcase(&1.name), &1.id})

      "newest" ->
        Enum.sort_by(sets, & &1.id, :desc)

      "meditations" ->
        Enum.sort_by(sets, &{-meditation_count(&1, stats), &1.id})

      _category ->
        Enum.sort_by(sets, &{Categories.position(&1.category), &1.id})
    end
  end

  def meditation_count(set, stats) do
    case Map.get(stats, set.id) do
      %{meditation_count: count} -> count
      nil -> 0
    end
  end

  @doc """
  What the app will draw for this set: `:served` when a publishable painting
  or portrait exists, `:unpublishable` when a painting is uploaded but still
  needs a description or a licence, `:missing` when there is nothing at all.

  The set's linked author must be preloaded; `Rosary.list_meditation_sets/0`
  does that.
  """
  def artwork_state(set) do
    cond do
      Rosary.artwork_record(set) -> :served
      set.image_key -> :unpublishable
      true -> :missing
    end
  end

  defp filter_by_category(sets, nil), do: sets

  defp filter_by_category(sets, category) do
    Enum.filter(sets, &(&1.category == category))
  end

  defp filter_by_label(sets, nil), do: sets
  defp filter_by_label(sets, "none"), do: Enum.filter(sets, &(&1.labels == []))

  defp filter_by_label(sets, label) do
    Enum.filter(sets, &(label in &1.labels))
  end

  defp filter_by_visibility(sets, "hidden", hidden_ids) do
    Enum.filter(sets, &MapSet.member?(hidden_ids, &1.id))
  end

  defp filter_by_visibility(sets, "all", _hidden_ids), do: sets

  # "visible" and anything unrecognised, including nil: the default.
  defp filter_by_visibility(sets, _visible, hidden_ids) do
    Enum.reject(sets, &MapSet.member?(hidden_ids, &1.id))
  end

  defp filter_by_completeness(sets, "complete", stats) do
    Enum.filter(
      sets,
      &(meditation_count(&1, stats) == Rosary.expected_meditation_count(&1.category))
    )
  end

  defp filter_by_completeness(sets, "incomplete", stats) do
    Enum.filter(
      sets,
      &(meditation_count(&1, stats) != Rosary.expected_meditation_count(&1.category))
    )
  end

  defp filter_by_completeness(sets, "empty", stats) do
    Enum.filter(sets, &(meditation_count(&1, stats) == 0))
  end

  defp filter_by_completeness(sets, _, _stats), do: sets

  defp filter_by_artwork(sets, state) when state in ~w(missing unpublishable served) do
    wanted = String.to_existing_atom(state)
    Enum.filter(sets, &(artwork_state(&1) == wanted))
  end

  defp filter_by_artwork(sets, _), do: sets

  defp filter_by_query(sets, nil), do: sets
  defp filter_by_query(sets, ""), do: sets

  defp filter_by_query(sets, query) do
    downcased_query = String.downcase(query)

    Enum.filter(sets, fn set ->
      matches?(set.name, downcased_query) ||
        matches?(set.description, downcased_query) ||
        matches?(set.author, downcased_query) ||
        Enum.any?(set.labels, &matches?(&1, downcased_query))
    end)
  end

  defp matches?(nil, _query), do: false

  defp matches?(value, query) do
    value
    |> String.downcase()
    |> String.contains?(query)
  end
end
