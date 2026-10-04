defmodule LumenViae.Rosary.Types.ScheduleDays do
  @moduledoc """
  The days one category is prayed on a schedule, in the app's words.
  """
  use Ash.TypedStruct

  typed_struct do
    field :category, :string, allow_nil?: false, description: "A category slug."

    field :days_prayed, :string,
      description:
        "The days the schedule prays it (`Monday, Thursday, Sundays of Advent`), or null when the schedule never reaches it: the Luminous on the traditional schedule, the Seven Sorrows on either."

    field :words, :string,
      allow_nil?: false,
      description:
        "What the app shows under the set's name: `days_prayed`, or for a set the schedule never reaches, when it is kept (`Fridays, and on her feast, September 15`; `Any day you choose`)."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :schedule_days
end
