defmodule LumenViae.Rosary.Types.ChantOccasion do
  @moduledoc """
  A sung set: the chants for an occasion in the order they are sung
  (`ChantOccasion` in the iOS app), Benediction, a visit, a sung Rosary.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "Stable (`benediction`); a month names it, and devices store it."

    field :title, :string, allow_nil?: false, description: "Its title (`Adoration and Blessing`)."
    field :note, :string, allow_nil?: false, description: "One line under the title."

    field :painting, :string,
      allow_nil?: false,
      description: "The painting it is shown in, by the apps' painting name."

    field :blocks, {:array, Types.ChantOccasionBlock},
      allow_nil?: false,
      description: "What happens, in order: each a rubric and the chants it leads to."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_occasion
end
