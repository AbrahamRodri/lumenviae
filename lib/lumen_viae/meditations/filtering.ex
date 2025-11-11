defmodule LumenViae.Meditations.Filtering do
  @moduledoc false

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
    |> filter_by_author(filters[:author])
    |> filter_by_query(filters[:query])
  end

  def blank_to_nil(""), do: nil
  def blank_to_nil(value), do: value

  defp filter_by_category(meditations, nil), do: meditations

  defp filter_by_category(meditations, category) do
    Enum.filter(meditations, fn meditation -> meditation.mystery.category == category end)
  end

  defp filter_by_author(meditations, nil), do: meditations

  defp filter_by_author(meditations, author) do
    Enum.filter(meditations, fn meditation -> meditation.author == author end)
  end

  defp filter_by_query(meditations, nil), do: meditations
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
end
