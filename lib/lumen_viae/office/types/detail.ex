defmodule LumenViae.Office.Types.Detail do
  @moduledoc """
  The calendar's second column, verbatim: usually the season, sometimes a
  commemoration, as a label and its text.
  """
  use Ash.TypedStruct

  typed_struct do
    field :label, :string
    field :text, :string
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_day_detail
end
