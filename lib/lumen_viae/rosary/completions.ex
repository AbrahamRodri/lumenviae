defmodule LumenViae.Rosary.Completions do
  @moduledoc """
  Secondary Context for rosary completions: every read and write of the
  `rosary_completions` table lives here and nowhere else.

  Completions are only ever reported alongside the set that was prayed, but
  this module returns set *ids*; `LumenViae.Rosary` looks the sets up in
  `LumenViae.Rosary.MeditationSets` and joins the two in memory.

  Private to `LumenViae.Rosary` - call the Primary Context instead of this
  module. See `docs/ARCHITECTURE.md` for the context rules.
  """

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary.Completions.Completion

  def create(attrs \\ %{}) do
    %Completion{}
    |> Completion.changeset(attrs)
    |> Repo.insert()
  end

  def count do
    Repo.aggregate(Completion, :count)
  end

  @doc """
  Attaches a looked-up place to a completion that has already been written.

  Returns `:ok` whatever happens. This is called from a background task
  well after the completion was reported, and by then there is nobody left
  to tell: the row may have been deleted with its set, or the lookup may
  disagree with the schema. Neither is worth crashing a task over.
  """
  def update_location(completion_id, location) when is_map(location) do
    case Repo.get(Completion, completion_id) do
      nil ->
        :ok

      completion ->
        completion
        |> Completion.changeset(location)
        |> Repo.update()
        |> case do
          {:ok, _completion} -> :ok
          {:error, _changeset} -> :ok
        end
    end
  end

  def count_in_range(start_at, end_at) do
    from(rc in Completion, where: rc.completed_at >= ^start_at and rc.completed_at <= ^end_at)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns `[{set_id, count}]` for every set that has been completed at least
  once, most completed first.
  """
  def count_by_set do
    Repo.all(
      from rc in Completion,
        group_by: rc.meditation_set_id,
        select: {rc.meditation_set_id, count(rc.id)},
        order_by: [desc: count(rc.id)]
    )
  end

  @doc """
  The most recent completions, newest first.
  """
  def list_recent(limit) do
    Repo.all(
      from rc in Completion,
        order_by: [desc: rc.completed_at],
        limit: ^limit
    )
  end

  @doc """
  `[{%Date{}, count}]` for completions in the range, one entry per local day
  that had at least one, oldest first.

  The day boundary is taken in `time_zone` rather than in UTC, because a
  Rosary prayed at nine in the evening in Texas belongs to that evening on
  the dashboard, not to the next morning. Postgres carries the zone database
  so the shift is done there; the application has no tz dependency.
  """
  def count_by_day(start_at, end_at, time_zone) do
    # Named with `selected_as` rather than repeated in the group and order
    # clauses. Ecto numbers each fragment's parameters separately, so three
    # copies of the same expression reach Postgres as `$1`, `$4` and `$5` -
    # which it reads as three different expressions and refuses to group by.
    #
    # The double `AT TIME ZONE` is not redundant. `completed_at` is
    # `timestamp without time zone`, and for a naive timestamp Postgres
    # reads `AT TIME ZONE zone` as "this value is already in `zone`" and
    # converts *out* of it - the opposite of what is wanted here, and
    # wrong by the offset rather than merely imprecise. A single conversion
    # therefore filed every Rosary prayed between seven in the evening and
    # midnight Central under the following day, which is a good part of the
    # praying that happens at all.
    #
    # So the value is first stamped as UTC, which is what it is, and only
    # then converted to the reporting zone.
    Repo.all(
      from rc in Completion,
        where: rc.completed_at >= ^start_at and rc.completed_at <= ^end_at,
        group_by: selected_as(:day),
        order_by: [asc: selected_as(:day)],
        select:
          {selected_as(
             fragment(
               "date_trunc('day', (? AT TIME ZONE 'UTC') AT TIME ZONE ?)::date",
               rc.completed_at,
               ^time_zone
             ),
             :day
           ), count(rc.id)}
    )
  end

  @doc """
  How many distinct sets have been completed at least once in the range.
  """
  def count_distinct_sets_in_range(start_at, end_at) do
    Repo.one(
      from rc in Completion,
        where: rc.completed_at >= ^start_at and rc.completed_at <= ^end_at,
        select: count(rc.meditation_set_id, :distinct)
    )
  end

  @doc """
  `[{set_id, count}]` for completions in the range, most completed first.
  """
  def count_by_set_in_range(start_at, end_at) do
    Repo.all(
      from rc in Completion,
        where: rc.completed_at >= ^start_at and rc.completed_at <= ^end_at,
        group_by: rc.meditation_set_id,
        select: {rc.meditation_set_id, count(rc.id)},
        order_by: [desc: count(rc.id)]
    )
  end

  @doc """
  `[{country, country_code, count}]` for completions in the range, most
  completed first. Rows whose lookup never produced a country are left out
  rather than grouped under a blank heading.
  """
  def count_by_country(start_at, end_at) do
    Repo.all(
      from rc in Completion,
        where: rc.completed_at >= ^start_at and rc.completed_at <= ^end_at,
        where: not is_nil(rc.country),
        group_by: [rc.country, rc.country_code],
        select: {rc.country, rc.country_code, count(rc.id)},
        order_by: [desc: count(rc.id), asc: rc.country]
    )
  end

  @doc """
  `[{city, region, country_code, count}]` for completions in the range,
  most completed first.

  Grouped by city *and* region, because a city name on its own is not a
  place: there is a Paris in Texas, and several dozen Springfields.
  """
  def count_by_city(start_at, end_at) do
    Repo.all(
      from rc in Completion,
        where: rc.completed_at >= ^start_at and rc.completed_at <= ^end_at,
        where: not is_nil(rc.city),
        group_by: [rc.city, rc.region, rc.country_code],
        select: {rc.city, rc.region, rc.country_code, count(rc.id)},
        order_by: [desc: count(rc.id), asc: rc.city]
    )
  end

  @doc """
  `%{source => count}` for completions in the range. Completions recorded
  before a source was stored answer to `nil`.
  """
  def count_by_source(start_at, end_at) do
    Repo.all(
      from rc in Completion,
        where: rc.completed_at >= ^start_at and rc.completed_at <= ^end_at,
        group_by: rc.source,
        select: {rc.source, count(rc.id)}
    )
    |> Map.new()
  end

  @doc """
  `%{true | false | nil => count}` for completions in the range: prayed
  aloud, prayed silently, or not reported either way.
  """
  def count_by_prayed_aloud(start_at, end_at) do
    Repo.all(
      from rc in Completion,
        where: rc.completed_at >= ^start_at and rc.completed_at <= ^end_at,
        group_by: rc.prayed_aloud,
        select: {rc.prayed_aloud, count(rc.id)}
    )
    |> Map.new()
  end

  @doc """
  How many completions in the range have a place attached.

  Read next to the range total, this says how much of the location picture
  is actually there - a map drawn from a fifth of the rows should be read
  as one, and without this number there is no way to tell.
  """
  def count_located_in_range(start_at, end_at) do
    Repo.one(
      from rc in Completion,
        where: rc.completed_at >= ^start_at and rc.completed_at <= ^end_at,
        where: not is_nil(rc.country_code),
        select: count(rc.id)
    )
  end
end
