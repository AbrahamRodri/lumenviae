defmodule LumenViae.CentralTime do
  @moduledoc """
  US Central time, calculated rather than looked up.

  Every completion is stored in UTC, and the only person who reads the
  analytics is in Central time, so "today" on the dashboard has to mean
  today in Chicago. Doing that with `DateTime.shift_zone/2` would mean
  taking on a timezone database as a dependency for one screen, so the two
  US rules are computed here instead: Central Daylight Time (UTC-5) runs
  from 2:00 local on the second Sunday in March to 2:00 local on the first
  Sunday in November, and Central Standard Time (UTC-6) covers the rest of
  the year.

  Expressed in UTC - which is what the stored timestamps are - that is
  08:00 UTC on the second Sunday in March through 07:00 UTC on the first
  Sunday in November.

  The zone *name* is also here, because Postgres does have the zone database
  and groups completions by local day with it (see
  `LumenViae.Rosary.Completions.count_by_day/3`). Both halves must agree on
  which zone is being reported, so both read it from this module.
  """

  @zone_name "America/Chicago"

  @standard_offset -6 * 3600
  @daylight_offset -5 * 3600

  @doc """
  The IANA name of the reporting zone, for the Postgres side of the same
  calculation.
  """
  def zone_name, do: @zone_name

  @doc """
  The given UTC moment as a naive-in-Central `DateTime`.

  The result still carries the `Etc/UTC` zone - nothing here can produce a
  correctly zoned `DateTime` without a zone database - so it is only fit for
  formatting and for taking the local date. Never store it or compare it
  against a real UTC timestamp.

  Accepts a `NaiveDateTime` too, and reads it as UTC. Ecto's `timestamps()`
  writes `inserted_at` and `updated_at` naive, and in this application those
  columns are UTC like every other timestamp - the type carries no zone, but
  the value has one.
  """
  def to_local(%DateTime{} = utc), do: DateTime.add(utc, offset(utc), :second)
  def to_local(%NaiveDateTime{} = naive), do: naive |> as_utc() |> to_local()

  @doc """
  Now, in Central.
  """
  def now, do: to_local(DateTime.utc_now())

  @doc """
  Today's date in Central, which is the day the dashboard means by "Today".
  """
  def today, do: now() |> DateTime.to_date()

  @doc """
  The UTC instant at which the given Central date begins.

  The offset is taken at midnight UTC on that date, so on the two changeover
  days the boundary can be an hour out. That moves at most one completion
  between two adjacent days on a chart, twice a year, which is well inside
  what this reporting is for.
  """
  def day_start(%Date{} = date) do
    midnight = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    DateTime.add(midnight, -offset(midnight), :second)
  end

  @doc """
  "CDT" or "CST" for the given UTC moment.
  """
  def abbreviation(utc), do: if(daylight?(utc), do: "CDT", else: "CST")

  @doc """
  A UTC timestamp as a full Central-time sentence, for timestamps a curator
  reads one at a time.

      "Aug 22, 2026 at 3:04 PM CDT"
  """
  def format(utc) do
    Calendar.strftime(to_local(utc), "%b %-d, %Y at %-I:%M %p ") <> abbreviation(utc)
  end

  @doc """
  The same moment, short enough to sit in a table cell.

      "Aug 22, 3:04 PM"
  """
  def format_short(utc) do
    Calendar.strftime(to_local(utc), "%b %-d, %-I:%M %p")
  end

  @doc """
  Whether Central Daylight Time is in effect at the given UTC moment.
  """
  def daylight?(%NaiveDateTime{} = naive), do: naive |> as_utc() |> daylight?()

  def daylight?(%DateTime{} = utc) do
    starts = DateTime.new!(nth_weekday(utc.year, 3, 7, 2), ~T[08:00:00], "Etc/UTC")
    ends = DateTime.new!(nth_weekday(utc.year, 11, 7, 1), ~T[07:00:00], "Etc/UTC")

    DateTime.compare(utc, starts) != :lt and DateTime.compare(utc, ends) == :lt
  end

  defp as_utc(%NaiveDateTime{} = naive), do: DateTime.from_naive!(naive, "Etc/UTC")

  defp offset(utc), do: if(daylight?(utc), do: @daylight_offset, else: @standard_offset)

  # The nth occurrence of a weekday in a month, with `day_of_week` in
  # `Date.day_of_week/1` terms (1 is Monday, 7 is Sunday).
  defp nth_weekday(year, month, day_of_week, n) do
    first = Date.new!(year, month, 1)
    offset_days = Integer.mod(day_of_week - Date.day_of_week(first), 7)
    Date.add(first, offset_days + (n - 1) * 7)
  end
end
