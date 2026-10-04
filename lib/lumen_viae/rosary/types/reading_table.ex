defmodule LumenViae.Rosary.Types.ReadingTable do
  @moduledoc """
  A titled two-column table in a reading: a mystery and its grace.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :title, :string, allow_nil?: false, description: "Its title."

    field :rows, {:array, Types.ReadingTableRow},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its rows, in order."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :reading_table
end
