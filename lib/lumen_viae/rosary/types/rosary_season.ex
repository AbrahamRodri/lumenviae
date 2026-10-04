defmodule LumenViae.Rosary.Types.RosarySeason do
  @moduledoc """
  One Lent or one Advent, with its first and last day.
  """
  use Ash.TypedStruct

  typed_struct do
    field :season, :string, allow_nil?: false, description: "`lent` or `advent`."

    field :starts_on, :date,
      allow_nil?: false,
      description: "Its first day: Ash Wednesday, or the first Sunday of Advent."

    field :ends_on, :date,
      allow_nil?: false,
      description:
        "Its last day, included: Holy Saturday, or December 24. Easter and Christmas are ordinary."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_season
end
