defmodule LumenViae.Rosary.Types.ScheduleWeekdays do
  @moduledoc """
  A schedule's category for each weekday, Monday to Saturday. Sunday
  follows the season: see `LumenViae.Rosary.Types.ScheduleSunday`.
  """
  use Ash.TypedStruct

  typed_struct do
    field :monday, :string, allow_nil?: false, description: "A category slug."
    field :tuesday, :string, allow_nil?: false, description: "A category slug."
    field :wednesday, :string, allow_nil?: false, description: "A category slug."
    field :thursday, :string, allow_nil?: false, description: "A category slug."
    field :friday, :string, allow_nil?: false, description: "A category slug."
    field :saturday, :string, allow_nil?: false, description: "A category slug."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :schedule_weekdays
end
