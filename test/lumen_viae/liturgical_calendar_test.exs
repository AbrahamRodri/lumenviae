defmodule LumenViae.LiturgicalCalendarTest do
  @moduledoc """
  The seasons the Sunday mysteries follow and the two weekly schedules,
  ported case for case from the iOS app's `ScheduleSeasonTests.swift` and
  `ScheduleWeekTests.swift`. The app computes the day's mysteries on the
  device with `ScheduleService`, and its traditional schedule must agree
  with this module on every date.
  """
  use ExUnit.Case, async: true

  alias LumenViae.LiturgicalCalendar

  doctest LumenViae.LiturgicalCalendar

  # ScheduleSeasonTests.swift

  describe "easter/1" do
    for {year, month, day, note} <- [
          {1943, 4, 25, "the latest Easter can fall"},
          {1961, 4, 2, nil},
          {2000, 4, 23, nil},
          {2008, 3, 23, nil},
          {2019, 4, 21, nil},
          {2024, 3, 31, nil},
          {2025, 4, 20, nil},
          {2026, 4, 5, nil},
          {2027, 3, 28, nil},
          {2038, 4, 25, nil},
          {2285, 3, 22, "the earliest, next after 1818"}
        ] do
      test "falls on the Church's date in #{year}#{if note, do: ", " <> note}" do
        assert LiturgicalCalendar.easter(unquote(year)) ==
                 Date.new!(unquote(year), unquote(month), unquote(day))
      end
    end

    test "is always a Sunday between March 22 and April 25" do
      for year <- 1900..2100 do
        easter = LiturgicalCalendar.easter(year)
        assert Date.day_of_week(easter) == 7, "Easter #{year} is not a Sunday"

        assert Date.compare(easter, Date.new!(year, 3, 22)) != :lt and
                 Date.compare(easter, Date.new!(year, 4, 25)) != :gt,
               "Easter #{year} is out of range"
      end
    end
  end

  describe "ash_wednesday/1" do
    for {year, month, day} <- [{2024, 2, 14}, {2025, 3, 5}, {2026, 2, 18}, {2027, 2, 10}] do
      test "falls on the Church's date in #{year}" do
        ash = LiturgicalCalendar.ash_wednesday(unquote(year))
        assert ash == Date.new!(unquote(year), unquote(month), unquote(day))
        assert Date.day_of_week(ash) == 3
      end
    end
  end

  describe "advent_start/1" do
    for {year, month, day} <- [
          {2021, 11, 28},
          # November 27 is itself a Sunday
          {2022, 11, 27},
          # as late as Advent begins
          {2023, 12, 3},
          {2024, 12, 1},
          {2025, 11, 30},
          {2026, 11, 29},
          {2027, 11, 28}
        ] do
      test "is the Sunday on or after November 27 in #{year}" do
        start = LiturgicalCalendar.advent_start(unquote(year))
        assert start == Date.new!(unquote(year), unquote(month), unquote(day))
        assert Date.day_of_week(start) == 7
      end
    end
  end

  describe "season/1" do
    test "Lent runs from Ash Wednesday up to Easter" do
      # Shrove Tuesday
      assert LiturgicalCalendar.season(~D[2026-02-17]) == :ordinary
      # Ash Wednesday
      assert LiturgicalCalendar.season(~D[2026-02-18]) == :lent
      # Palm Sunday
      assert LiturgicalCalendar.season(~D[2026-03-29]) == :lent
      # Holy Saturday
      assert LiturgicalCalendar.season(~D[2026-04-04]) == :lent
      # Easter Sunday
      assert LiturgicalCalendar.season(~D[2026-04-05]) == :ordinary
    end

    test "Advent runs from its first Sunday through Christmas Eve" do
      assert LiturgicalCalendar.season(~D[2026-11-28]) == :ordinary
      assert LiturgicalCalendar.season(~D[2026-11-29]) == :advent
      assert LiturgicalCalendar.season(~D[2026-12-24]) == :advent
      # Christmastide counts as ordinary here
      assert LiturgicalCalendar.season(~D[2026-12-25]) == :ordinary
    end

    # The app's case reads two instants a minute either side of midnight
    # in a fixed time zone. The server is handed the calendar day itself,
    # so the same case is the two days either side of that midnight.
    test "a season turns at midnight, not at noon" do
      assert LiturgicalCalendar.season(~D[2026-02-17]) == :ordinary
      assert LiturgicalCalendar.season(~D[2026-02-18]) == :lent
    end
  end

  # ScheduleWeekTests.swift

  describe "week/1" do
    test "the traditional week has no Luminous" do
      assert LiturgicalCalendar.week(:traditional) == [:joyful, :sorrowful, :glorious]
    end

    test "the modern week adds the Luminous after the Glorious" do
      assert LiturgicalCalendar.week(:modern) == [:joyful, :sorrowful, :glorious, :luminous]
    end

    # Every set the week names is one the grid shows, so no weekday's
    # mysteries are only behind VIEW ALL
    for schedule <- [:traditional, :modern] do
      test "every weekday's set is in the #{schedule} week" do
        week = LiturgicalCalendar.week(unquote(schedule))

        for category <- LiturgicalCalendar.categories(), category != :seven_sorrows do
          prayed = LiturgicalCalendar.days_prayed(category, unquote(schedule)) != nil
          assert category in week == prayed, "#{category} on #{unquote(schedule)}"
        end
      end
    end
  end

  # The rest is the server's own.

  describe "recommended_mysteries/2" do
    test "follows the traditional schedule when none is named" do
      # Thursday and Saturday, 1 and 3 October 2026
      assert LiturgicalCalendar.recommended_mysteries(~D[2026-10-01]) == :joyful
      assert LiturgicalCalendar.recommended_mysteries(~D[2026-10-03]) == :glorious
    end

    test "differs on the modern schedule only on Thursday and Saturday" do
      for date <- Date.range(~D[2026-09-28], ~D[2026-10-04]) do
        traditional = LiturgicalCalendar.recommended_mysteries(date, :traditional)
        modern = LiturgicalCalendar.recommended_mysteries(date, :modern)

        case Date.day_of_week(date) do
          4 -> assert {traditional, modern} == {:joyful, :luminous}
          6 -> assert {traditional, modern} == {:glorious, :joyful}
          _ -> assert traditional == modern
        end
      end
    end

    test "keeps Sunday by season on the modern schedule" do
      # First Sunday of Advent, the second of Lent, Easter Sunday
      assert LiturgicalCalendar.recommended_mysteries(~D[2026-11-29], :modern) == :joyful
      assert LiturgicalCalendar.recommended_mysteries(~D[2026-03-01], :modern) == :sorrowful
      assert LiturgicalCalendar.recommended_mysteries(~D[2026-04-05], :modern) == :glorious
    end

    # Each line of the fixture is the app's ScheduleService, compiled and
    # asked for every day of a year; see the fixture's header.
    @app_answers "test/support/fixtures/ios_schedule/2025-2027.txt"
                 |> File.read!()
                 |> String.split("\n", trim: true)
                 |> Enum.reject(&String.starts_with?(&1, "#"))
                 |> Enum.map(&String.split/1)

    @letters %{"J" => :joyful, "S" => :sorrowful, "G" => :glorious, "L" => :luminous}

    test "gives the app's answer for every date of 2025, 2026 and 2027 on both schedules" do
      assert length(@app_answers) == 6

      for [schedule, year, answers] <- @app_answers do
        schedule = String.to_existing_atom(schedule)
        year = String.to_integer(year)
        dates = Date.range(Date.new!(year, 1, 1), Date.new!(year, 12, 31))
        expected = answers |> String.graphemes() |> Enum.map(&Map.fetch!(@letters, &1))

        assert Enum.count(dates) == length(expected)

        for {date, app} <- Enum.zip(dates, expected) do
          assert LiturgicalCalendar.recommended_mysteries(date, schedule) == app,
                 "#{date} on #{schedule}"
        end
      end
    end
  end

  describe "days_prayed/2 and days_in_words/2" do
    # The app's words, ScheduleService.daysPrayed and
    # MysteryCategory.daysPrayed, for each set on each schedule
    @words [
      {:traditional, :joyful, "Monday, Thursday, Sundays of Advent"},
      {:traditional, :sorrowful, "Tuesday, Friday, Sundays of Lent"},
      {:traditional, :glorious, "Wednesday, Saturday, Sunday"},
      {:traditional, :luminous, nil},
      {:traditional, :seven_sorrows, nil},
      {:modern, :joyful, "Monday, Saturday, Sundays of Advent"},
      {:modern, :sorrowful, "Tuesday, Friday, Sundays of Lent"},
      {:modern, :glorious, "Wednesday, Sunday"},
      {:modern, :luminous, "Thursday"},
      {:modern, :seven_sorrows, nil}
    ]

    for {schedule, category, words} <- @words do
      test "say the #{category} days on the #{schedule} schedule as the app does" do
        assert LiturgicalCalendar.days_prayed(unquote(category), unquote(schedule)) ==
                 unquote(words)
      end
    end

    test "say when a set no schedule reaches is kept" do
      for schedule <- LiturgicalCalendar.schedules() do
        assert LiturgicalCalendar.days_in_words(:seven_sorrows, schedule) ==
                 "Fridays, and on her feast, September 15"
      end

      assert LiturgicalCalendar.days_in_words(:luminous, :traditional) == "Any day you choose"
      assert LiturgicalCalendar.days_in_words(:luminous, :modern) == "Thursday"

      assert LiturgicalCalendar.days_in_words(:joyful, :traditional) ==
               "Monday, Thursday, Sundays of Advent"
    end
  end

  describe "seasons/1" do
    test "dates every Lent and Advent so that every other day is ordinary" do
      ranges = LiturgicalCalendar.seasons(2025..2028)
      assert length(ranges) == 8

      for date <- Date.range(~D[2025-01-01], ~D[2028-12-31]) do
        found =
          Enum.find_value(ranges, :ordinary, fn %{season: season} = range ->
            if Date.compare(date, range.starts_on) != :lt and
                 Date.compare(date, range.ends_on) != :gt,
               do: season
          end)

        assert found == LiturgicalCalendar.season(date), "#{date}"
      end
    end

    test "are in calendar order and never overlap" do
      ranges = LiturgicalCalendar.seasons(2024..2030)

      ranges
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert Date.compare(a.ends_on, b.starts_on) == :lt
      end)
    end
  end
end
