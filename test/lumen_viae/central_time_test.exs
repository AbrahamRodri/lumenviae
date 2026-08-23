defmodule LumenViae.CentralTimeTest do
  @moduledoc """
  The DST rule is computed rather than looked up, so the two changeover
  dates are the whole risk: get them wrong and every completion on the
  dashboard sits in the wrong hour for half the year.
  """
  use ExUnit.Case, async: true

  alias LumenViae.CentralTime

  defp utc(iso), do: iso |> DateTime.from_iso8601() |> elem(1)

  describe "daylight?/1" do
    # 2026: DST runs from the second Sunday in March (the 8th) to the first
    # Sunday in November (the 1st).
    test "is off before the second Sunday in March" do
      refute CentralTime.daylight?(utc("2026-01-15T12:00:00Z"))
      refute CentralTime.daylight?(utc("2026-03-08T07:59:00Z"))
    end

    test "switches on at 08:00 UTC on the second Sunday in March" do
      assert CentralTime.daylight?(utc("2026-03-08T08:00:00Z"))
      assert CentralTime.daylight?(utc("2026-06-15T12:00:00Z"))
    end

    test "switches off at 07:00 UTC on the first Sunday in November" do
      assert CentralTime.daylight?(utc("2026-11-01T06:59:00Z"))
      refute CentralTime.daylight?(utc("2026-11-01T07:00:00Z"))
      refute CentralTime.daylight?(utc("2026-12-25T12:00:00Z"))
    end

    test "tracks the rule into other years rather than a fixed date" do
      # 2027: March 14 and November 7.
      refute CentralTime.daylight?(utc("2027-03-14T07:59:00Z"))
      assert CentralTime.daylight?(utc("2027-03-14T08:00:00Z"))
      assert CentralTime.daylight?(utc("2027-11-07T06:59:00Z"))
      refute CentralTime.daylight?(utc("2027-11-07T07:00:00Z"))
    end
  end

  describe "to_local/1" do
    test "shifts five hours back in summer and six in winter" do
      assert CentralTime.to_local(utc("2026-07-04T18:00:00Z")).hour == 13
      assert CentralTime.to_local(utc("2026-01-04T18:00:00Z")).hour == 12
    end

    test "reads a naive timestamp as UTC, the way Ecto writes them" do
      naive = ~N[2026-07-04 18:00:00]

      assert CentralTime.to_local(naive) == CentralTime.to_local(utc("2026-07-04T18:00:00Z"))
    end
  end

  describe "day_start/1" do
    # The reason this exists: a Rosary prayed at nine in the evening in Texas
    # is 02:00 UTC the next day, and must still count as that evening.
    test "a Central day begins at 05:00 or 06:00 UTC" do
      assert CentralTime.day_start(~D[2026-07-04]) == utc("2026-07-04T05:00:00Z")
      assert CentralTime.day_start(~D[2026-01-04]) == utc("2026-01-04T06:00:00Z")
    end
  end

  describe "formatting" do
    test "prints the zone it actually used" do
      assert CentralTime.format(utc("2026-07-04T18:00:00Z")) == "Jul 4, 2026 at 1:00 PM CDT"
      assert CentralTime.format(utc("2026-01-04T18:00:00Z")) == "Jan 4, 2026 at 12:00 PM CST"
    end

    test "the short form drops the year and the zone" do
      assert CentralTime.format_short(utc("2026-07-04T18:00:00Z")) == "Jul 4, 1:00 PM"
    end
  end

  describe "zone_name/0" do
    test "names the same zone Postgres is asked to group by" do
      assert CentralTime.zone_name() == "America/Chicago"
      assert LumenViae.Rosary.reporting_time_zone() == CentralTime.zone_name()
    end
  end
end
