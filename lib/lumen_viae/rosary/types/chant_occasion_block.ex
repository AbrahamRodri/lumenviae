defmodule LumenViae.Rosary.Types.ChantOccasionBlock do
  @moduledoc """
  One part of an occasion (`ChantOccasionBlock` in the iOS app): the
  rubric, printed in red, and the chants it leads to, sung `rounds` over.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :rubric, :string, description: "What happens before its chants, or null."

    field :steps, {:array, Types.ChantOccasionStep},
      allow_nil?: false,
      description: "Its chants, in order."

    field :rounds, :integer,
      allow_nil?: false,
      description:
        "How many times the steps are sung through: 5 for the Rosary's decades, else 1."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_occasion_block
end
