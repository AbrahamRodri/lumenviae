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

  # What the iOS app says about each category (MysteryCategory.swift),
  # word for word: its short name, the line under it on every card, how
  # many mysteries it has, how many Hail Marys a decade holds, and whether
  # the Fatima Prayer closes a decade. The Seven Sorrows chaplet is seven
  # sorrows of seven Hail Marys, closed by the Glory Be alone.
  @details %{
    "joyful" => %{
      name: "Joyful",
      subtitle: "Jesus' birth and childhood",
      mysteries: 5,
      hail_marys: 10,
      fatima_prayer: true
    },
    "sorrowful" => %{
      name: "Sorrowful",
      subtitle: "Jesus' suffering and death",
      mysteries: 5,
      hail_marys: 10,
      fatima_prayer: true
    },
    "glorious" => %{
      name: "Glorious",
      subtitle: "The Resurrection",
      mysteries: 5,
      hail_marys: 10,
      fatima_prayer: true
    },
    "luminous" => %{
      name: "Luminous",
      subtitle: "Jesus' public life",
      mysteries: 5,
      hail_marys: 10,
      fatima_prayer: true
    },
    "seven_sorrows" => %{
      name: "Seven Sorrows",
      subtitle: "Mary in her grief",
      mysteries: 7,
      hail_marys: 7,
      fatima_prayer: false
    }
  }

  @ordinals ~w(First Second Third Fourth Fifth Sixth Seventh)

  # The seven graces Our Lady promises, by the tradition handed down
  # through St. Bridget of Sweden, to those who honour her sorrows daily:
  # the app's MysteriesInScriptureData.sevenGraces, word for word.
  @seven_graces [
    "Peace in their families.",
    "Enlightenment about the divine mysteries.",
    "Consolation in their pains, and her companionship in their work.",
    "Whatever they ask, so long as it accords with God's will and the good of their souls.",
    "Defence in their spiritual battles, and protection at every instant of their lives.",
    "Visible help at the moment of death \u2014 they will see the face of their Mother.",
    "Her Son's mercy for those who spread this devotion, that they may be brought from this life to eternal happiness."
  ]

  @keys for {_label, slug} <- @categories,
            order <- 1..@details[slug].mysteries,
            do: "#{slug}_#{order}"

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

  @doc """
  The short name the app gives a category: "Joyful", "Seven Sorrows".
  """
  def name(slug), do: @details |> Map.fetch!(slug) |> Map.fetch!(:name)

  @doc """
  The devotion's full title as a reader meets it: "Joyful Mysteries",
  "Seven Sorrows of Mary". The same words as `label/1`.
  """
  def devotion_title(slug) do
    case slug do
      "seven_sorrows" -> "Seven Sorrows of Mary"
      slug -> "#{name(slug)} Mysteries"
    end
  end

  @doc """
  What the mysteries are about, in everyday words: the line under the name
  on every card in the app.
  """
  def subtitle(slug), do: @details |> Map.fetch!(slug) |> Map.fetch!(:subtitle)

  @doc "How many mysteries the category has: 5, or 7 for the Seven Sorrows."
  def mystery_count(slug), do: @details |> Map.fetch!(slug) |> Map.fetch!(:mysteries)

  @doc "How many Hail Marys a decade holds: 10, or 7 in a sorrow of the chaplet."
  def hail_marys(slug), do: @details |> Map.fetch!(slug) |> Map.fetch!(:hail_marys)

  @doc """
  Whether the Fatima Prayer closes each decade, after the Glory Be. Not in
  the Seven Sorrows chaplet, whose sorrows close on the Glory Be alone.
  """
  def fatima_prayer?(slug), do: @details |> Map.fetch!(slug) |> Map.fetch!(:fatima_prayer)

  @doc """
  The label for one mystery by its position, as the app sets it: "The
  First Joyful Mystery", or, in the chaplet, "The First Sorrow of Mary".
  """
  def mystery_label(slug, order) when order in 1..7 do
    ordinal = Enum.at(@ordinals, order - 1)

    case slug do
      "seven_sorrows" -> "The #{ordinal} Sorrow of Mary"
      slug -> "The #{ordinal} #{name(slug)} Mystery"
    end
  end

  @doc """
  Each mystery's label in order: `mystery_label/2` for every position the
  category has.
  """
  def mystery_labels(slug), do: Enum.map(1..mystery_count(slug), &mystery_label(slug, &1))

  @doc """
  The graces promised to those who pray the category: the seven of the
  Seven Sorrows, and none for the others.
  """
  def graces("seven_sorrows"), do: @seven_graces
  def graces(_slug), do: []

  @doc """
  Every mystery's key, `<category>_<order>`, in the order they are prayed:
  the 27 mysteries the app knows. Anything keyed by a mystery uses them.
  """
  def mystery_keys, do: @keys
end
