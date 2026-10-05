defmodule LumenViae.Rosary.Completion.PlaceCounts do
  @moduledoc """
  Where and on what the completions of a range were prayed, counted by
  Postgres in a handful of grouped queries rather than by reading every
  row: `%{countries:, cities:, sources:, prayed_aloud:, located:, total:}`.

  Each grouping answers a few dozen rows at most, so the ranking is done
  here, by the same rule as before (most first, then by name in Elixir's
  ordering, not the database's collation), and the figures are exactly
  those the old fold produced.

  Ash has no GROUP BY, so this is one of the domain's sanctioned Ecto
  queries (docs/ARCHITECTURE.md).
  """
  use Ash.Resource.Actions.Implementation

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary.Completion

  @impl true
  def run(input, _opts, _context) do
    %{since: since, until: until} = input.arguments

    in_range =
      from(c in Completion, where: c.completed_at >= ^since and c.completed_at <= ^until)

    {total, located} =
      from(c in in_range,
        select: {count(), filter(count(), not is_nil(c.country_code))}
      )
      |> Repo.one()

    {:ok,
     %{
       # Rows whose lookup never produced a country are left out rather
       # than grouped under a blank heading.
       countries:
         from(c in in_range,
           where: not is_nil(c.country),
           group_by: [c.country, c.country_code],
           select: {{c.country, c.country_code}, count()}
         )
         |> Repo.all()
         |> ranked()
         |> Enum.map(fn {{country, code}, count} ->
           %{country: country, country_code: code, count: count}
         end),
       # By city *and* region, because a city name on its own is not a
       # place: there is a Paris in Texas, and several dozen Springfields.
       cities:
         from(c in in_range,
           where: not is_nil(c.city),
           group_by: [c.city, c.region, c.country_code],
           select: {{c.city, c.region, c.country_code}, count()}
         )
         |> Repo.all()
         |> ranked()
         |> Enum.map(fn {{city, region, code}, count} ->
           %{city: city, region: region, country_code: code, count: count}
         end),
       # Completions recorded before a source was stored answer to `nil`.
       sources:
         from(c in in_range, group_by: c.source, select: {c.source, count()})
         |> Repo.all()
         |> Map.new(),
       # true, false, or nil for not reported either way.
       prayed_aloud:
         from(c in in_range, group_by: c.prayed_aloud, select: {c.prayed_aloud, count()})
         |> Repo.all()
         |> Map.new(),
       located: located,
       total: total
     }}
  end

  # Most frequent first, then by name, so two places prayed from equally
  # often always come out in the same order.
  defp ranked(groups) do
    Enum.sort_by(groups, fn {group, count} -> {-count, elem(group, 0)} end)
  end
end
