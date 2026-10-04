defmodule LumenViae.Rosary.Types.RosaryVerses do
  @moduledoc """
  One mystery's Scriptural Rosary verses, in bead order: ten to a
  mystery, seven to a sorrow. GraphQL has no map type, so the section is a
  list of these, each carrying its mystery's key.
  """
  use Ash.TypedStruct

  typed_struct do
    field :key, :string, allow_nil?: false, description: "The mystery's key: `joyful_1`."

    field :verses, {:array, LumenViae.Rosary.Types.RosaryVerse},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "One verse per Hail Mary, in bead order."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_verses
end
