defmodule LumenViae.Rosary.Types.RosaryCategory do
  @moduledoc """
  One category of mysteries as the `categories` section of
  `GET /api/v2/rosary-content` serves it. See `LumenViae.Rosary.Categories`.
  """
  use Ash.TypedStruct

  typed_struct do
    field :slug, :string,
      allow_nil?: false,
      description: "`joyful`, `sorrowful`, `glorious`, `luminous` or `seven_sorrows`."

    field :name, :string, allow_nil?: false, description: "Its short name: `Joyful`."

    field :devotion_title, :string,
      allow_nil?: false,
      description: "Its full title: `Joyful Mysteries`, `Seven Sorrows of Mary`."

    field :subtitle, :string,
      allow_nil?: false,
      description: "What its mysteries are about, in everyday words."

    field :mystery_labels, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Each mystery's label by position, from the first: `The First Joyful Mystery`, `The First Sorrow of Mary`. As many as the category has mysteries."

    field :hail_marys, :integer,
      allow_nil?: false,
      description: "Hail Marys in a decade: 10, or 7 in a sorrow of the chaplet."

    field :fatima_prayer, :boolean,
      allow_nil?: false,
      description:
        "Whether the Fatima Prayer follows the Glory Be at the end of each decade. False for the Seven Sorrows."

    field :graces, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The graces promised to those who pray it: the seven of the Seven Sorrows, empty for the others."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_category
end
