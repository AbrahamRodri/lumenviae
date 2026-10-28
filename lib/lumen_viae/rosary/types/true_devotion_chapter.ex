defmodule LumenViae.Rosary.Types.TrueDevotionChapter do
  @moduledoc """
  One chapter of True Devotion, with every paragraph in reading order.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description:
        "The chapter's id (`introduction`, `motives`). Stable forever: a device keeps a reader's progress by it."

    field :part, :integer,
      allow_nil?: false,
      description:
        "The part it belongs to, a `number` in `parts`, or 0 for the Introduction, which is in none."

    field :title, :string,
      allow_nil?: false,
      description: "The chapter's title (`Motives for This Devotion`)."

    field :paragraphs, {:array, Types.TrueDevotionParagraph},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its paragraphs in reading order, their ids 0, 1, 2 and on."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :true_devotion_chapter
end
