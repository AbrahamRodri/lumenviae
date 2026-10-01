defmodule LumenViae.Office.Types.Section do
  @moduledoc """
  One section of an hour, in reading order: the Latin and, unless the hour
  was asked for in Latin alone, the translation beside it.
  """
  use Ash.TypedStruct

  typed_struct do
    field :latin, LumenViae.Office.Types.Cell
    field :vernacular, LumenViae.Office.Types.Cell
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_section
end
