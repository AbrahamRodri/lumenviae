defmodule LumenViae.Rosary.Types.RosarySchedule do
  @moduledoc """
  Which mysteries a day calls for, as rules a client applies on the device:
  the `schedule` section of `GET /api/v2/rosary-content`, from
  `LumenViae.LiturgicalCalendar`. See docs/JSON_API.md, "The content
  document", for how a client applies it.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :default, :string,
      allow_nil?: false,
      description:
        "The id of the schedule a client follows until its reader chooses another: `traditional`."

    field :schedules, {:array, Types.MysterySchedule},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The weekly schedules, the default first. A client should pass over a schedule whose id it does not know."

    field :seasons, {:array, Types.RosarySeason},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Every Lent and Advent from `seasons_from` through `seasons_through`, in calendar order. A date inside one is in that season; every other date in the range is `ordinary`, Christmastide and Eastertide included."

    field :seasons_from, :date,
      allow_nil?: false,
      description:
        "The first date `seasons` answers for: January 1 of last year. The range moves on when the year turns, and with it the document's version."

    field :seasons_through, :date,
      allow_nil?: false,
      description: "The last date `seasons` answers for: December 31 three years ahead."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_schedule
end
