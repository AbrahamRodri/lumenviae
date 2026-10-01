defmodule LumenViae.Office.Types.Day do
  @moduledoc """
  One day's place in the calendar, without any of its hours.
  """
  use Ash.TypedStruct

  typed_struct do
    field :date, :date, allow_nil?: false
    field :celebration, LumenViae.Office.Types.Celebration
    field :detail, LumenViae.Office.Types.Detail
    field :note, :string
    field :letter, :string
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_day
end
