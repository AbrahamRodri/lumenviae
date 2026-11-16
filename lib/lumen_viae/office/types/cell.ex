defmodule LumenViae.Office.Types.Cell do
  @moduledoc """
  One column of one section of an hour: the Latin, or the translation
  beside it. `lines` is never null; a cell the engine left empty has none.
  `marked_lines` is the same lines with a rubric the engine prints inside
  a line set in braces ("word and deed: {strikes his breast} through my
  fault"), or null when the cell has none; `lines` runs it in, as it
  always has.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string
    field :note, :string
    field :lines, {:array, :string}, allow_nil?: false, default: []
    field :marked_lines, {:array, :string}
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_cell
end
