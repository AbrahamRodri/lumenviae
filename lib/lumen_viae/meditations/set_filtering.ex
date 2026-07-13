defmodule LumenViae.Meditations.SetFiltering do
  @moduledoc """
  In-memory filtering and sorting for the admin meditation sets list.

  All filter keys are optional; a nil (or absent) value leaves the list
  untouched.

  Supported filter keys:

    * `:category` - set category string ("joyful", "sorrowful", ...)
    * `:label` - sets carrying this exact label
    * `:visibility` - "visible" or "hidden" (requires the MapSet of hidden
      set ids from `Rosary.hidden_meditation_set_ids/0`)
    * `:completeness` - "complete", "incomplete" (wrong meditation count for
      the category), or "empty" (requires the stats map from
      `Rosary.meditation_set_stats/0`)
    * `:query` - case-insensitive match against name, description, and labels
  """

  @category_order %{"joyful" => 0, "sorrowful" => 1, "glorious" => 2, "seven_sorrows" => 3}

  @doc """
  Number of meditations a set of the given category is expected to hold.
  """
  def expected_meditation_count("seven_sorrows"), do: 7
  def expected_meditation_count(_category), do: 5

  def filter_sets(sets, filters, context \\ %{}) do
    hidden_ids = Map.get(context, :hidden_ids, MapSet.new())
    stats = Map.get(context, :stats, %{})

    sets
    |> filter_by_category(filters[:category])
    |> filter_by_label(filters[:label])
    |> filter_by_visibility(filters[:visibility], hidden_ids)
    |> filter_by_completeness(filters[:completeness], stats)
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
        Enum.sort_by(sets, &{Map.get(@category_order, &1.category, 99), &1.id})
    end
  end

  def meditation_count(set, stats) do
    case Map.get(stats, set.id) do
      %{meditation_count: count} -> count
      nil -> 0
    end
  end

  defp filter_by_category(sets, nil), do: sets

  defp filter_by_category(sets, category) do
    Enum.filter(sets, &(&1.category == category))
  end

  defp filter_by_label(sets, nil), do: sets

  defp filter_by_label(sets, label) do
    Enum.filter(sets, &(label in &1.labels))
  end

  defp filter_by_visibility(sets, "visible", hidden_ids) do
    Enum.reject(sets, &MapSet.member?(hidden_ids, &1.id))
  end

  defp filter_by_visibility(sets, "hidden", hidden_ids) do
    Enum.filter(sets, &MapSet.member?(hidden_ids, &1.id))
  end

  defp filter_by_visibility(sets, _, _hidden_ids), do: sets

  defp filter_by_completeness(sets, "complete", stats) do
    Enum.filter(sets, &(meditation_count(&1, stats) == expected_meditation_count(&1.category)))
  end

  defp filter_by_completeness(sets, "incomplete", stats) do
    Enum.filter(sets, &(meditation_count(&1, stats) != expected_meditation_count(&1.category)))
  end

  defp filter_by_completeness(sets, "empty", stats) do
    Enum.filter(sets, &(meditation_count(&1, stats) == 0))
  end

  defp filter_by_completeness(sets, _, _stats), do: sets

  defp filter_by_query(sets, nil), do: sets
  defp filter_by_query(sets, ""), do: sets

  defp filter_by_query(sets, query) do
    downcased_query = String.downcase(query)

    Enum.filter(sets, fn set ->
      matches?(set.name, downcased_query) ||
        matches?(set.description, downcased_query) ||
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
