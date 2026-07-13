defmodule LumenViae.Meditations.Filtering do
  @moduledoc """
  In-memory filtering and sorting for admin meditation lists.

  All filter keys are optional; a nil (or absent) value leaves the list
  untouched, so callers that only use a subset of the filters keep working.

  Supported filter keys:

    * `:category` - mystery category string ("joyful", "sorrowful", ...)
    * `:mystery_id` - integer id of a specific mystery
    * `:author` - exact author string
    * `:audio` - "with" or "without" an audio file
    * `:status` - "active" or "archived" (nil shows both)
    * `:set_id` - integer set id, or `:none` for meditations in no set
      (requires `meditation_sets` to be preloaded)
    * `:query` - case-insensitive match against title, author, source,
      mystery name, and content
  """

  @category_order %{"joyful" => 0, "sorrowful" => 1, "glorious" => 2, "seven_sorrows" => 3}

  def available_authors(meditations) do
    meditations
    |> Enum.map(&(&1.author || ""))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  def filter_meditations(meditations, filters) do
    meditations
    |> filter_by_category(filters[:category])
    |> filter_by_mystery(filters[:mystery_id])
    |> filter_by_author(filters[:author])
    |> filter_by_audio(filters[:audio])
    |> filter_by_status(filters[:status])
    |> filter_by_set(filters[:set_id])
    |> filter_by_query(filters[:query])
  end

  @doc """
  Sorts meditations. Supported orders: "mystery" (category, then mystery
  order, then id), "newest", "oldest", "updated", "author", "title".
  Unknown values fall back to "mystery".
  """
  def sort_meditations(meditations, sort) do
    case sort do
      "newest" ->
        Enum.sort_by(meditations, & &1.id, :desc)

      "oldest" ->
        Enum.sort_by(meditations, & &1.id, :asc)

      "updated" ->
        Enum.sort_by(meditations, &{&1.updated_at, &1.id}, :desc)

      "author" ->
        Enum.sort_by(meditations, &{is_nil(&1.author), &1.author || "", &1.id})

      "title" ->
        Enum.sort_by(meditations, &{is_nil(&1.title), &1.title || "", &1.id})

      _mystery ->
        Enum.sort_by(meditations, fn m ->
          {Map.get(@category_order, m.mystery.category, 99), m.mystery.order, m.id}
        end)
    end
  end

  def blank_to_nil(""), do: nil
  def blank_to_nil(value), do: value

  defp filter_by_category(meditations, nil), do: meditations

  defp filter_by_category(meditations, category) do
    Enum.filter(meditations, fn meditation -> meditation.mystery.category == category end)
  end

  defp filter_by_mystery(meditations, nil), do: meditations

  defp filter_by_mystery(meditations, mystery_id) do
    Enum.filter(meditations, fn meditation -> meditation.mystery_id == mystery_id end)
  end

  defp filter_by_author(meditations, nil), do: meditations

  defp filter_by_author(meditations, author) do
    Enum.filter(meditations, fn meditation -> meditation.author == author end)
  end

  defp filter_by_audio(meditations, "with") do
    Enum.filter(meditations, &has_audio?/1)
  end

  defp filter_by_audio(meditations, "without") do
    Enum.reject(meditations, &has_audio?/1)
  end

  defp filter_by_audio(meditations, _), do: meditations

  defp filter_by_status(meditations, "active") do
    Enum.filter(meditations, &is_nil(&1.archived_at))
  end

  defp filter_by_status(meditations, "archived") do
    Enum.reject(meditations, &is_nil(&1.archived_at))
  end

  defp filter_by_status(meditations, _), do: meditations

  defp filter_by_set(meditations, nil), do: meditations

  defp filter_by_set(meditations, :none) do
    Enum.filter(meditations, fn meditation -> meditation.meditation_sets == [] end)
  end

  defp filter_by_set(meditations, set_id) do
    Enum.filter(meditations, fn meditation ->
      Enum.any?(meditation.meditation_sets, &(&1.id == set_id))
    end)
  end

  defp filter_by_query(meditations, nil), do: meditations
  defp filter_by_query(meditations, ""), do: meditations

  defp filter_by_query(meditations, query) do
    downcased_query = String.downcase(query)

    Enum.filter(meditations, fn meditation ->
      matches?(meditation.title, downcased_query) ||
        matches?(meditation.author, downcased_query) ||
        matches?(meditation.source, downcased_query) ||
        matches?(meditation.mystery.name, downcased_query) ||
        matches?(meditation.content, downcased_query)
    end)
  end

  defp has_audio?(meditation) do
    meditation.audio_url not in [nil, ""]
  end

  defp matches?(nil, _query), do: false

  defp matches?(value, query) do
    value
    |> String.downcase()
    |> String.contains?(query)
  end
end
