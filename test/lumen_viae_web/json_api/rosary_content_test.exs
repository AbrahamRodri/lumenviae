defmodule LumenViaeWeb.JsonApi.RosaryContentTest do
  @moduledoc """
  `GET /api/v2/rosary-content`: the Rosary's words as one document. The
  bare request is the version and the date, which is how a device asks
  whether its saved copy is current; the sections come when named in
  `fields[rosary_content]=`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.LiturgicalCalendar
  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.RosaryContent.Current
  alias LumenViae.Rosary.RosaryContent.Schedule

  # The strict form the app's ISO8601DateFormatter accepts: whole seconds, Z.
  @instant ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

  test "the bare request carries the version and the date, and nothing else", %{conn: conn} do
    conn = get_v2(conn, "/rosary-content")
    body = v2_response(conn, 200)

    assert %{"type" => "rosary_content", "id" => "current", "attributes" => attributes} =
             body["data"]

    assert Map.keys(attributes) |> Enum.sort() == ["updated_at", "version"]
    %{version: version, updated_at: updated_at} = Current.stamp()
    assert attributes["version"] == version
    assert attributes["updated_at"] =~ @instant
    assert attributes["updated_at"] == DateTime.to_iso8601(updated_at)

    assert get_resp_header(conn, "cache-control") == ["private, no-store"]
  end

  test "the version is the same on every request", %{conn: conn} do
    versions =
      for _ <- 1..3 do
        conn
        |> get_v2("/rosary-content")
        |> v2_response(200)
        |> get_in(["data", "attributes", "version"])
      end

    assert [version, version, version] = versions
  end

  test "the prayers come when asked for, all twelve, in the order they are said", %{conn: conn} do
    attributes =
      conn
      |> get_v2("/rosary-content?fields[rosary_content]=version,prayers")
      |> v2_response(200)
      |> get_in(["data", "attributes"])

    assert Map.keys(attributes) |> Enum.sort() == ["prayers", "version"]

    prayers = attributes["prayers"]

    assert Enum.map(prayers, & &1["id"]) == Content.prayer_ids()

    for prayer <- prayers do
      assert Map.keys(prayer) |> Enum.sort() == ~w(group id text title)
      assert length(prayer["text"]["en"]) == length(prayer["text"]["la"])
    end

    # Exactly the words the server holds, line for line.
    assert prayers == Content.prayers()
  end

  test "the Hail Mary, as a client reads it", %{conn: conn} do
    prayers =
      conn
      |> get_v2("/rosary-content?fields[rosary_content]=prayers")
      |> v2_response(200)
      |> get_in(["data", "attributes", "prayers"])

    assert %{
             "id" => "hail_mary",
             "group" => "rosary",
             "title" => %{"en" => "The Hail Mary", "la" => "Ave Maria"},
             "text" => %{
               "en" => ["Hail Mary, full of grace, the Lord is with thee;" | _],
               "la" => ["Ave Maria, gratia plena, Dominus tecum;" | _]
             }
           } = Enum.find(prayers, &(&1["id"] == "hail_mary"))
  end

  describe "the schedule" do
    setup %{conn: conn} do
      schedule =
        conn
        |> get_v2("/rosary-content?fields[rosary_content]=schedule")
        |> v2_response(200)
        |> get_in(["data", "attributes", "schedule"])

      %{schedule: schedule}
    end

    test "is the calendar's, as served this year", %{schedule: schedule} do
      assert schedule == Schedule.section(Schedule.current_year())
      assert schedule["default"] == "traditional"
      assert Enum.map(schedule["schedules"], & &1["id"]) == ["traditional", "modern"]
    end

    test "serves the seasons from last year through three years ahead", %{schedule: schedule} do
      year = Schedule.current_year()

      assert schedule["seasons_from"] == "#{year - 1}-01-01"
      assert schedule["seasons_through"] == "#{year + 3}-12-31"
      assert length(schedule["seasons"]) == 10
    end

    test "gives the home grid the week's sets in order, then the Seven Sorrows",
         %{schedule: schedule} do
      grids = Map.new(schedule["schedules"], &{&1["id"], &1["grid"]})

      assert grids == %{
               "traditional" => ~w(joyful sorrowful glorious seven_sorrows),
               "modern" => ~w(joyful sorrowful glorious luminous seven_sorrows)
             }
    end

    test "says the days each set is prayed in the app's words", %{schedule: schedule} do
      modern = Enum.find(schedule["schedules"], &(&1["id"] == "modern"))

      assert Enum.map(modern["days"], &{&1["category"], &1["days_prayed"], &1["words"]}) == [
               {"joyful", "Monday, Saturday, Sundays of Advent",
                "Monday, Saturday, Sundays of Advent"},
               {"sorrowful", "Tuesday, Friday, Sundays of Lent",
                "Tuesday, Friday, Sundays of Lent"},
               {"glorious", "Wednesday, Sunday", "Wednesday, Sunday"},
               {"luminous", "Thursday", "Thursday"},
               {"seven_sorrows", nil, "Fridays, and on her feast, September 15"}
             ]
    end

    # The acceptance test: a client that applies the section as
    # docs/JSON_API.md describes gets the calendar's answer for every date
    # it serves, on both schedules.
    test "applied as a client applies it, gives the calendar's category for every date served",
         %{schedule: schedule} do
      from = Date.from_iso8601!(schedule["seasons_from"])
      through = Date.from_iso8601!(schedule["seasons_through"])

      for rules <- schedule["schedules"],
          date <- Date.range(from, through) do
        schedule_id = String.to_existing_atom(rules["id"])

        assert apply_schedule(schedule, rules, date) ==
                 Atom.to_string(LiturgicalCalendar.recommended_mysteries(date, schedule_id)),
               "#{date} on #{rules["id"]}"
      end
    end
  end

  # What a client does with the section, from the served JSON alone.
  @weekdays ~w(monday tuesday wednesday thursday friday saturday)

  defp apply_schedule(schedule, rules, date) do
    case Date.day_of_week(date) do
      7 -> rules["sunday"][season_of(schedule, date)]
      day -> rules["weekdays"][Enum.at(@weekdays, day - 1)]
    end
  end

  defp season_of(schedule, date) do
    iso = Date.to_iso8601(date)

    Enum.find_value(schedule["seasons"], "ordinary", fn season ->
      if season["starts_on"] <= iso and iso <= season["ends_on"], do: season["season"]
    end)
  end
end
