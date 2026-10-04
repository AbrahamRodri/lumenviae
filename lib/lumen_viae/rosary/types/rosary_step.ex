defmodule LumenViae.Rosary.Types.RosaryStep do
  @moduledoc """
  One step of how to pray the Rosary.
  """
  use Ash.TypedStruct

  typed_struct do
    field :number, :integer, allow_nil?: false, description: "Its number, from 1."
    field :title, :string, allow_nil?: false, description: "What to do."
    field :detail, :string, allow_nil?: false, description: "How, in a sentence or two."

    field :prayer_ids, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The prayers said at it, in order (ids in the `prayers` section); empty for a step that names none."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_step
end
