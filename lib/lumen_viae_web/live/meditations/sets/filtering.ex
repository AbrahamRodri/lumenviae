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
    * `:visibility` - "visible", "hidden", "archived", "empty" or "all"
      (requires the MapSet of hidden set ids from
      `LumenViae.Rosary.hidden_meditation_set_ids/0`, and the stats map to
      tell the two kinds of hidden apart). "hidden" is every hidden set;
      "archived" is the ones holding an archived meditation and "empty" the
      ones with no meditations yet, which are the two reasons a set is
      hidden. The list defaults to "visible": the admin's normal question
      is about what the public is being served, and a set out of
      circulation is noise in the answer.
    * `:completeness` - "complete" or "incomplete" (wrong meditation count
      for the category; requires the stats map from
      `LumenViae.Rosary.meditation_set_stats/0`). A set with no meditations
      at all is hidden, so it is found under `:visibility`.
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
    |> filter_by_visibility(filters[:visibility], hidden_ids, stats)
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
  Why the public cannot see this set, or nil when it can: `:empty` when it
  has no meditations yet, `:archived` when it holds an archived one. An
  empty set holds nothing, so the two never overlap.
  """
  def hidden_reason(set, hidden_ids, stats) do
    cond do
      not MapSet.member?(hidden_ids, set.id) -> nil
      meditation_count(set, stats) == 0 -> :empty
      true -> :archived
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

  defp filter_by_visibility(sets, "hidden", hidden_ids, _stats) do
    Enum.filter(sets, &MapSet.member?(hidden_ids, &1.id))
  end

  defp filter_by_visibility(sets, reason, hidden_ids, stats) when reason in ~w(archived empty) do
    wanted = String.to_existing_atom(reason)
    Enum.filter(sets, &(hidden_reason(&1, hidden_ids, stats) == wanted))
  end

  defp filter_by_visibility(sets, "all", _hidden_ids, _stats), do: sets

  # "visible" and anything unrecognised, including nil: the default.
  defp filter_by_visibility(sets, _visible, hidden_ids, _stats) do
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
