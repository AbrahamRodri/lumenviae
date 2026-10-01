defmodule LumenViae.Office.Types.Cell do
  @moduledoc """
  One column of one section of an hour: the Latin, or the translation
  beside it. `lines` is never null; a cell the engine left empty has none.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string
    field :note, :string
    field :lines, {:array, :string}, allow_nil?: false, default: []
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_cell
end
