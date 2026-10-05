defmodule LumenViae.Rosary.Completion.DailyCounts do
  @moduledoc """
  How many completions fell on each calendar day of a range, counted by
  Postgres in one grouped query: `[%{date: %Date{}, count: integer}]`,
  days with none left out.

  Ash has no GROUP BY, so this is one of the domain's sanctioned Ecto
  queries (docs/ARCHITECTURE.md). The day is bucketed exactly as
  `Completion`'s `local_day` calculation buckets it; see the comment there
  for why the zone is applied twice.
  """
  use Ash.Resource.Actions.Implementation

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary.Completion

  @impl true
  def run(input, _opts, _context) do
    %{since: since, until: until, time_zone: zone} = input.arguments

    days =
      from(c in Completion,
        where: c.completed_at >= ^since and c.completed_at <= ^until,
        select: %{
          day:
            fragment(
              "date_trunc('day', (? AT TIME ZONE 'UTC') AT TIME ZONE ?)::date",
              c.completed_at,
              ^zone
            )
        }
      )

    counts =
      from(d in subquery(days),
        group_by: d.day,
        order_by: d.day,
        select: %{date: d.day, count: count()}
      )
      |> Repo.all()

    {:ok, counts}
  end
end
