defmodule LumenViae.Rosary.Types.RosaryAnatomy do
  @moduledoc """
  One part of a rosary, as a beginner learns it.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string, allow_nil?: false, description: "Its id."
    field :name, :string, allow_nil?: false, description: "Its name."
    field :prayed, :string, allow_nil?: false, description: "What is prayed there."

    field :parts, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The beads it names (keys in `parts`), in the order the fingers travel them."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_anatomy
end
