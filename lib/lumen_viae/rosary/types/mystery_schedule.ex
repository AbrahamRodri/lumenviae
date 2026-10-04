defmodule LumenViae.Rosary.Types.MysterySchedule do
  @moduledoc """
  One weekly schedule of the Rosary's mysteries: the mysteries of each
  weekday, Sunday's by season, the order of the app's home grid and the
  days each set is prayed in words. See `LumenViae.LiturgicalCalendar`.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description:
        "`traditional` (Joyful on Thursday, Glorious on Saturday) or `modern` (Rosarium Virginis Mariae 38: Luminous on Thursday, Joyful on Saturday)."

    field :weekdays, Types.ScheduleWeekdays,
      allow_nil?: false,
      description:
        "The category of each day from Monday to Saturday. The day is the device's calendar day, turning at midnight; not the prayer day that turns at four in the morning."

    field :sunday, Types.ScheduleSunday,
      allow_nil?: false,
      description: "Sunday's category, by the season the Sunday falls in (see `seasons`)."

    field :grid, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Category slugs in the order the home grid shows them: the sets the week prays, in the week's order from Monday, then the Seven Sorrows."

    field :days, {:array, Types.ScheduleDays},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Each of the five categories, in the app's order, with the days it is prayed in words."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :mystery_schedule
end
