defmodule LumenViae.Office.Types.Calendar do
  @moduledoc """
  One month of the liturgical calendar under one set of rubrics, its days
  in date order.
  """
  use Ash.TypedStruct

  typed_struct do
    field :year, :integer, allow_nil?: false
    field :month, :integer, allow_nil?: false
    field :version, :string, allow_nil?: false

    field :days, {:array, LumenViae.Office.Types.Day},
      allow_nil?: false,
      constraints: [nil_items?: false]
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_calendar
end
