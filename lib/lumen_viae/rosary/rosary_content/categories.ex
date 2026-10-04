defmodule LumenViae.Rosary.RosaryContent.Categories do
  @moduledoc """
  The `categories` section of `LumenViae.Rosary.RosaryContent`: the five
  categories in the order the app presents them, from
  `LumenViae.Rosary.Categories`.

  The section is fixed, so it is dated here: change what it serves, and
  move `@updated_at` and the pinned version in
  test/lumen_viae/rosary/rosary_content_sections_test.exs.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Categories
  alias LumenViae.Rosary.Types

  @updated_at ~U[2026-10-04 00:00:00Z]

  @impl true
  def calculate(records, _opts, _context) do
    categories = all()

    Enum.map(records, fn _record -> categories end)
  end

  @doc "Every category, in the order the app presents them."
  @spec all() :: [Types.RosaryCategory.t()]
  def all, do: Enum.map(Categories.slugs(), &shape/1)

  @doc "When what this section serves last changed."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: @updated_at

  defp shape(slug) do
    %Types.RosaryCategory{
      slug: slug,
      name: Categories.name(slug),
      devotion_title: Categories.devotion_title(slug),
      subtitle: Categories.subtitle(slug),
      mystery_labels: Categories.mystery_labels(slug),
      hail_marys: Categories.hail_marys(slug),
      fatima_prayer: Categories.fatima_prayer?(slug),
      graces: Categories.graces(slug)
    }
  end
end
