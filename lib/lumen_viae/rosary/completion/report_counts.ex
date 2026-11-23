defmodule LumenViae.Rosary.Completion.ReportCounts do
  @moduledoc """
  The console's Completions screen, counted by Postgres in grouped queries
  rather than by reading the matching rows: how many, by day, set, surface,
  aloud, country, city and hour, for completions since a moment (or ever)
  narrowed by any of set, surface, country and prayed aloud.

  Also two counts that ignore some of the filters, for the filter bar:
  `period_total` (the period with no other filter, for "Showing N of M")
  and `country_options` (the countries of the period with every filter but
  the country, so choosing one does not leave it the only choice).

  Ash has no GROUP BY, so this is one of the domain's sanctioned Ecto
  queries (docs/ARCHITECTURE.md). Days and hours are bucketed as
  `Completion`'s `local_day` calculation buckets them; see the comment
  there for why the zone is applied twice.
  """
  use Ash.Resource.Actions.Implementation

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary.Completion

  @impl true
  def run(input, _opts, _context) do
    args = input.arguments
    zone = args.time_zone
    period = in_period(args)
    matching = narrowed(period, args)

    {total, located} =
      from(c in matching, select: {count(), filter(count(), not is_nil(c.country_code))})
      |> Repo.one()

    {:ok,
     %{
       total: total,
       located: located,
       period_total: Repo.aggregate(period, :count),
       by_day:
         from(c in matching,
           group_by: 1,
           select:
             {fragment(
                "date_trunc('day', (? AT TIME ZONE 'UTC') AT TIME ZONE ?)::date",
                c.completed_at,
                ^zone
              ), count()}
         )
         |> Repo.all()
         |> Map.new(),
       hours:
         from(c in matching,
           group_by: 1,
           select:
             {fragment(
                "extract(hour from (? AT TIME ZONE 'UTC') AT TIME ZONE ?)::integer",
                c.completed_at,
                ^zone
              ), count()}
         )
         |> Repo.all()
         |> Map.new(),
       # By id only: the domain names them (no join here).
       sets:
         from(c in matching,
           group_by: c.meditation_set_id,
           select: {{c.meditation_set_id}, count()}
         )
         |> Repo.all()
         |> ranked()
         |> Enum.map(fn {{id}, count} -> %{set_id: id, count: count} end),
       sources:
         from(c in matching, group_by: c.source, select: {c.source, count()})
         |> Repo.all()
         |> Map.new(),
       prayed_aloud:
         from(c in matching, group_by: c.prayed_aloud, select: {c.prayed_aloud, count()})
         |> Repo.all()
         |> Map.new(),
       countries: countries(matching),
       country_options: countries(narrowed(period, Map.put(args, :country_code, nil))),
       cities:
         from(c in matching,
           where: not is_nil(c.city),
           group_by: [c.city, c.region, c.country_code],
           select: {{c.city, c.region, c.country_code}, count()}
         )
         |> Repo.all()
         |> ranked()
         |> Enum.map(fn {{city, region, code}, count} ->
           %{city: city, region: region, country_code: code, count: count}
         end)
     }}
  end

  defp in_period(%{since: nil}), do: from(c in Completion)
  defp in_period(%{since: since}), do: from(c in Completion, where: c.completed_at >= ^since)

  defp narrowed(query, args) do
    Enum.reduce(
      [:meditation_set_id, :source, :country_code, :prayed_aloud],
      query,
      fn field, query ->
        case Map.get(args, field) do
          nil -> query
          value -> from(c in query, where: field(c, ^field) == ^value)
        end
      end
    )
  end

  defp countries(query) do
    from(c in query,
      where: not is_nil(c.country),
      group_by: [c.country, c.country_code],
      select: {{c.country, c.country_code}, count()}
    )
    |> Repo.all()
    |> ranked()
    |> Enum.map(fn {{country, code}, count} ->
      %{country: country, country_code: code, count: count}
    end)
  end

  # Most frequent first, then by name, so two groups counted equally often
  # always come out in the same order.
  defp ranked(groups) do
    Enum.sort_by(groups, fn {group, count} -> {-count, elem(group, 0)} end)
  end
end
