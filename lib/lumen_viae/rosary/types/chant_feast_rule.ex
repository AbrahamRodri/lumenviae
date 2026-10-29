defmodule LumenViae.Rosary.Types.ChantFeastRule do
  @moduledoc """
  How a chant feast's date is found in a year (`ChantFeast.Rule` in the
  iOS app). The arithmetic is the device's.
  """
  use Ash.TypedStruct

  typed_struct do
    field :kind, :string,
      allow_nil?: false,
      description:
        "`fixed` (the same `month` and `day` every year), `easter` (`days_from_easter` after Easter Sunday: Pentecost is 49, Good Friday -2), `last_sunday_of_october` (Christ the King) or `holy_name` (the Sunday between 2 and 5 January, else 2 January)."

    field :month, :integer, description: "For `fixed`: its month, 1 to 12. Null otherwise."
    field :day, :integer, description: "For `fixed`: its day of the month. Null otherwise."

    field :days_from_easter, :integer,
      description: "For `easter`: days after Easter Sunday, negative before it. Null otherwise."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_feast_rule
end
