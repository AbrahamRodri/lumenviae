defmodule LumenViae.Rosary.Categories do
  @moduledoc """
  The controlled vocabulary of mystery categories.

  Both mysteries and meditation sets are filed under one of these
  categories, and the slug is what gets written to the database, appears in
  URLs, and is matched by the iOS app. The list is ordered the way the
  categories are presented everywhere in the app: the three traditional
  sets first, then the Luminous Mysteries, then the Seven Sorrows.

  This is a value module, not a context: it holds no state and touches no
  database, so any layer may call it directly (see `LumenViae.Rosary.Labels`
  for the other vocabulary of its kind).
  """

  @categories [
    {"Joyful Mysteries", "joyful"},
    {"Sorrowful Mysteries", "sorrowful"},
    {"Glorious Mysteries", "glorious"},
    {"Luminous Mysteries", "luminous"},
    {"Seven Sorrows of Mary", "seven_sorrows"}
  ]

  @slugs Enum.map(@categories, fn {_label, slug} -> slug end)

  @order @categories |> Enum.with_index() |> Map.new(fn {{_label, slug}, i} -> {slug, i} end)

  @doc """
  Returns `{label, slug}` pairs in display order, shaped for form selects.
  """
  def options, do: @categories

  @doc """
  Returns just the category slugs, for changeset validation.
  """
  def slugs, do: @slugs

  @doc """
  Returns the display label for a slug, falling back to the slug itself so
  an unrecognised value renders as something rather than blank.
  """
  def label(slug) do
    case List.keyfind(@categories, slug, 1) do
      {label, ^slug} -> label
      nil -> slug
    end
  end

  @doc """
  Returns the sort position of a category, used to order mixed lists of
  mysteries and sets the way the app presents them. Unknown categories sort
  last.
  """
  def position(slug), do: Map.get(@order, slug, length(@slugs))
end
