defmodule LumenViae.Rosary.Types.ReadingTableRow do
  @moduledoc """
  One row of a reading's table.
  """
  use Ash.TypedStruct

  typed_struct do
    field :label, :string, allow_nil?: false, description: "The left column."
    field :value, :string, allow_nil?: false, description: "The right column."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :reading_table_row
end
