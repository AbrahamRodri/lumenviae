defmodule LumenViae.Rosary.Types.ChantGroup do
  @moduledoc """
  A group of chants, in the Parish Book of Chant's order.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string, allow_nil?: false, description: "The group's id. Stable forever."
    field :title, :string, allow_nil?: false, description: "Its title."
    field :note, :string, description: "What it holds, in one line, or null."

    field :parts, {:array, Types.ChantGroupPart},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its parts in order."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_group
end
