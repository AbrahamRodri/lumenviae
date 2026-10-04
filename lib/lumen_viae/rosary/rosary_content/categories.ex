defmodule LumenViae.Rosary.RosaryContent.Categories do
  @moduledoc """
  The `categories` section of `LumenViae.Rosary.RosaryContent`: the five
  categories in the order the app presents them, from
  `LumenViae.Rosary.Categories`, each with the painting its card shows.

  Most of it is fixed in code (`fixed/0`), so it is dated here: change what
  that serves, and move `@updated_at` and the pinned version in
  test/lumen_viae/rosary/rosary_content_sections_test.exs. A card's own
  painting (`card_artwork`) is a `LumenViae.Rosary.CategoryCard` row, read
  from the database (`all/1`), and dated by the row (`cards_updated_at/1`).
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Artwork
  alias LumenViae.Rosary.Artwork.Published
  alias LumenViae.Rosary.Categories
  alias LumenViae.Rosary.CategoryCard
  alias LumenViae.Rosary.Types

  @updated_at ~U[2026-10-04 03:00:00Z]

  @impl true
  def calculate(records, _opts, context) do
    categories = context |> Ash.Context.to_opts() |> all()

    Enum.map(records, fn _record -> categories end)
  end

  @doc """
  Every category, in the order the app presents them, with each card's own
  painting where one is published. `opts` are the caller's, for the read.
  """
  @spec all(keyword) :: [Types.RosaryCategory.t()]
  def all(opts \\ []) do
    cards = opts |> cards() |> Map.new(&{&1.slug, &1})

    Enum.map(fixed(), fn category ->
      card = Map.get(cards, category.slug)
      %{category | card_artwork: if(Artwork.publishable?(card), do: Published.shape(card))}
    end)
  end

  @doc "The categories as code alone gives them: no card painting."
  @spec fixed() :: [Types.RosaryCategory.t()]
  def fixed, do: Enum.map(Categories.slugs(), &shape/1)

  @doc "When what is fixed in code last changed."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: @updated_at

  @doc "When a card's row last changed, or nil when there is no card."
  @spec cards_updated_at(keyword) :: DateTime.t() | nil
  def cards_updated_at(opts \\ []) do
    opts |> cards() |> Enum.map(& &1.updated_at) |> Enum.max(DateTime, fn -> nil end)
  end

  defp cards(opts) do
    CategoryCard |> Ash.Query.for_read(:read, %{}, opts) |> Ash.read!()
  end

  defp shape(slug) do
    {focal_x, focal_y} = Categories.card_focal_point(slug)

    %Types.RosaryCategory{
      slug: slug,
      name: Categories.name(slug),
      devotion_title: Categories.devotion_title(slug),
      subtitle: Categories.subtitle(slug),
      mystery_labels: Categories.mystery_labels(slug),
      hail_marys: Categories.hail_marys(slug),
      fatima_prayer: Categories.fatima_prayer?(slug),
      card_mystery_key: Categories.card_mystery_key(slug),
      card_focal_x: focal_x,
      card_focal_y: focal_y,
      card_artwork: nil,
      graces: Categories.graces(slug)
    }
  end
end
