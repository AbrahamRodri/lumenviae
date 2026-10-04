defmodule LumenViae.Rosary.Types.RosaryMilestone do
  @moduledoc """
  A named devotional milestone, reached by praying a number of consecutive days. See docs/JSON_API.md, "The content document", for when one fires and how its name and title are made.
  """
  use Ash.TypedStruct

  typed_struct do
    field :days, :integer,
      allow_nil?: false,
      description:
        "The consecutive days of prayer. The milestone is earned at exactly this streak."

    field :meaning, :string,
      description:
        "What the Church calls a run of this length, in plain words (`a novena`), where it has a name. Shown after the days, never alone. Null where it has none."

    field :icon, :string,
      allow_nil?: false,
      description:
        "The glyph on the milestone's badge, by the iOS app's icon name: a numeral (`ph-number-circle-nine`) or a named devotion's sign (`lv-rosary`). An Android client draws its own for each name."

    field :blessing, :string,
      allow_nil?: false,
      description: "The line shown when the milestone is reached."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_milestone
end
