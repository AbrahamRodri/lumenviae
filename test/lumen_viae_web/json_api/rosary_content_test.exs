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
  alias LumenViae.Rosary.RosaryContent.Labels, as: LabelsSection
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

  describe "the companion sections" do
    @sections ~w(quotes milestones reminders labels forms)

    test "come when asked for, and not before", %{conn: conn} do
      bare =
        conn |> get_v2("/rosary-content") |> v2_response(200) |> get_in(["data", "attributes"])

      assert Map.keys(bare) |> Enum.sort() == ["updated_at", "version"]

      attributes =
        conn
        |> get_v2("/rosary-content?fields[rosary_content]=#{Enum.join(@sections, ",")}")
        |> v2_response(200)
        |> get_in(["data", "attributes"])

      assert Map.keys(attributes) |> Enum.sort() == Enum.sort(@sections)
    end

    test "are the files' and the vocabulary's, as they are held", %{conn: conn} do
      attributes =
        conn
        |> get_v2("/rosary-content?fields[rosary_content]=#{Enum.join(@sections, ",")}")
        |> v2_response(200)
        |> get_in(["data", "attributes"])

      assert attributes["quotes"] == Content.quotes()
      assert attributes["milestones"] == Content.milestones()
      assert attributes["reminders"] == Content.reminders()
      assert attributes["forms"] == Content.forms()
      assert attributes["labels"] == LabelsSection.section()
    end

    test "count what the app has", %{conn: conn} do
      attributes =
        conn
        |> get_v2("/rosary-content?fields[rosary_content]=#{Enum.join(@sections, ",")}")
        |> v2_response(200)
        |> get_in(["data", "attributes"])

      assert length(attributes["quotes"]["items"]) == 21
      assert length(attributes["milestones"]) == 12

      assert Enum.map(attributes["reminders"]["groups"], &length(&1["messages"])) == [
               7,
               7,
               7,
               2,
               7
             ]

      assert length(attributes["labels"]["labels"]) == 5
      assert length(attributes["labels"]["kinds"]) == 4
      assert Enum.map(attributes["forms"]["choices"], & &1["id"]) == ~w(audio counting)
    end

    test "are folded into the version, so a word changed moves it" do
      for section <- @sections, do: assert(section in Current.folded_sections())

      changed =
        update_in(Content.document(), ["quotes", "items", Access.at(0), "text"], &(&1 <> "!"))

      refute Content.version(changed) == Content.version(Content.document())
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

  describe "the How to Pray course" do
    test "learn and guided_rosary come when asked for, as the files hold them", %{conn: conn} do
      attributes =
        conn
        |> get_v2("/rosary-content?fields[rosary_content]=learn,guided_rosary")
        |> v2_response(200)
        |> get_in(["data", "attributes"])

      assert Map.keys(attributes) |> Enum.sort() == ["guided_rosary", "learn"]
      assert attributes["learn"] == Content.learn()
      assert attributes["guided_rosary"] == Content.guided_rosary()
    end

    test "a guided step, as a client reads it", %{conn: conn} do
      rosaries =
        conn
        |> get_v2("/rosary-content?fields[rosary_content]=guided_rosary")
        |> v2_response(200)
        |> get_in(["data", "attributes", "guided_rosary", "rosaries"])

      %{"steps" => steps} = Enum.find(rosaries, &(&1["category"] == "sorrowful"))

      assert Enum.at(steps, 11) == %{
               "part" => "loopSmall.0.2",
               "place" => "The Agony in the Garden · 3 of 10",
               "instruction" => "Stay with the Agony in the Garden.",
               "prayer_ids" => ["hail_mary"],
               "decade" => 0,
               "announcement" => false,
               "closing" => false
             }
    end
  end

  describe "lang" do
    @sections "version,updated_at,prayers,learn,guided_rosary,schedule,script,mysteries,categories,verses,quotes,milestones,reminders,labels,forms"

    defp attributes(conn, query) do
      conn
      |> get_v2("/rosary-content?fields[rosary_content]=#{@sections}" <> query)
      |> v2_response(200)
      |> get_in(["data", "attributes"])
    end

    test "missing, en or a language not served: the English document, word for word",
         %{conn: conn} do
      english = attributes(conn, "")

      for query <- ["&lang=en", "&lang=EN", "&lang=fr", "&lang=", "&lang=spanish"] do
        assert attributes(build_conn(), query) == english, query
      end

      for prayer <- english["prayers"] do
        assert Map.keys(prayer["title"]) |> Enum.sort() == ["en", "la"]
        assert Map.keys(prayer["text"]) |> Enum.sort() == ["en", "la"]
      end

      assert english["version"] == Current.stamp().version
    end

    test "es: every prayer in Spanish beside the English and Latin", %{conn: conn} do
      spanish = attributes(conn, "&lang=es")
      english = attributes(build_conn(), "")

      assert spanish["prayers"] == Content.prayers("es")

      assert %{
               "id" => "hail_mary",
               "title" => %{"es" => "Ave María"},
               "text" => %{
                 "es" => ["Dios te salve, María, llena eres de gracia; el Señor es contigo." | _]
               }
             } = Enum.find(spanish["prayers"], &(&1["id"] == "hail_mary"))

      # The prayers, mysteries and categories have Spanish
      # (rosary_content_mysteries_test.exs); every other section is the English.
      assert Map.drop(spanish, ~w(prayers mysteries categories version updated_at)) ==
               Map.drop(english, ~w(prayers mysteries categories version updated_at))
    end

    test "es has a version and a date of its own, and a region reads as es", %{conn: conn} do
      spanish = attributes(conn, "&lang=es")
      english = attributes(build_conn(), "")

      refute spanish["version"] == english["version"]
      assert spanish["version"] == Current.stamp(Schedule.current_year(), [], "es").version
      # The document's date is the latest of every section's, the schedule's
      # included, and never earlier than the Spanish file's.
      stamp = Current.stamp(Schedule.current_year(), [], "es")
      assert spanish["updated_at"] == DateTime.to_iso8601(stamp.updated_at)

      [%{updated_at: spanish_file_at}] = Content.spanish_files()
      refute DateTime.compare(stamp.updated_at, spanish_file_at) == :lt
      assert attributes(build_conn(), "&lang=es-MX") == spanish
    end

    test "the bare request with es is the Spanish version and date alone", %{conn: conn} do
      attributes =
        conn
        |> get_v2("/rosary-content?lang=es")
        |> v2_response(200)
        |> get_in(["data", "attributes"])

      assert Map.keys(attributes) |> Enum.sort() == ["updated_at", "version"]
      assert attributes["version"] == Current.stamp(Schedule.current_year(), [], "es").version
    end
  end
end
