defmodule LumenViaeWeb.JsonApi.OfficeTest do
  @moduledoc """
  The Divine Office under `/api/v2/office`, end to end: the v2 router, the
  Breviary resource's actions and the Office domain beneath them, with
  Req.Test answering for the engine with saved pages.

  The office cache is shared across the suite, so these tests keep to
  dates in 1904, which no other test file uses (GraphQL's keep to 1903,
  the REST Office tests to 1901 and 1902).
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Office.DivinumOfficium

  # A cache of this test's own, so no other test's entries answer for it.
  setup do
    LumenViae.Office.Cache.isolate()
    :ok
  end

  @fixtures Path.expand("../../support/fixtures/divinum_officium", __DIR__)

  defp stub_page(name) do
    html = File.read!(Path.join(@fixtures, name))
    test_pid = self()

    Req.Test.stub(DivinumOfficium, fn conn ->
      send(test_pid, {:asked, conn.params})
      Req.Test.html(conn, html)
    end)
  end

  describe "GET /office/days/:date/hours/:hour" do
    test "answers the hour in the same words as GraphQL and v1", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      hour = conn |> get_v2("/office/days/1904-03-04/hours/laudes") |> v2_response(200)

      assert hour["date"] == "1904-03-04"
      assert hour["hour"] == "laudes"
      assert hour["version"] == "rubrics-1960"
      assert hour["language"] == "english"

      assert hour["celebration"] == %{
               "title" => "S. Bartholomæi Apostoli",
               "rank" => "II. classis"
             }

      assert length(hour["sections"]) == 11

      [incipit | _rest] = hour["sections"]
      assert incipit["latin"]["title"] == "Incipit"
      assert incipit["vernacular"]["title"] == "Start"
      assert hd(incipit["latin"]["lines"]) == "℣. Deus ✠ in adiutórium meum inténde."

      assert hour["source"]["name"] == "The Divinum Officium Project"
      assert hour["source"]["url"] =~ "divinumofficium.com"
    end

    test "passes version and language through to the engine", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      hour =
        conn
        |> get_v2(
          "/office/days/1904-03-05/hours/laudes?version=divino-afflatu-1954&language=latin"
        )
        |> v2_response(200)

      assert hour["version"] == "divino-afflatu-1954"
      assert hour["language"] == "latin"
    end

    test "an unknown hour is a 400 naming the valid hours", %{conn: conn} do
      body = conn |> get_v2("/office/days/1904-03-07/hours/brunch") |> v2_response(400)

      assert [%{"code" => "invalid_argument", "detail" => detail}] = body["errors"]
      assert detail =~ "unknown hour"
      assert detail =~ "completorium"
    end

    test "a date outside the engine's window is a 400", %{conn: conn} do
      body = conn |> get_v2("/office/days/1492-10-12/hours/laudes") |> v2_response(400)

      assert [%{"code" => "invalid_argument", "detail" => detail}] = body["errors"]
      assert detail =~ "between 1600 and 2200"
    end

    test "engine trouble is a 503 office_unavailable the client can retry", %{conn: conn} do
      Req.Test.stub(DivinumOfficium, fn conn -> Req.Test.transport_error(conn, :timeout) end)

      body = conn |> get_v2("/office/days/1904-03-08/hours/laudes") |> v2_response(503)

      assert [%{"code" => "office_unavailable", "detail" => detail}] = body["errors"]
      assert detail == "Divine Office temporarily unavailable"
    end
  end

  describe "GET /office/days/:date/hours" do
    test "answers all eight hours of a date in liturgical order", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      hours = conn |> get_v2("/office/days/1904-03-09/hours") |> v2_response(200)

      assert Enum.map(hours, & &1["hour"]) ==
               ~w(matutinum laudes prima tertia sexta nona vesperae completorium)
    end
  end

  describe "GET /office/days/:date" do
    test "answers the day's calendar entry", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      day = conn |> get_v2("/office/days/1904-08-24") |> v2_response(200)

      assert day["date"] == "1904-08-24"

      assert day["celebration"] == %{
               "title" => "S. Bartholomæi Apostoli",
               "rank" => "II. classis"
             }

      assert Map.keys(day) |> Enum.sort() == ~w(celebration date detail letter note)
    end
  end

  describe "GET /office/calendar/:year/:month" do
    test "answers the month, its days in date order", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      calendar = conn |> get_v2("/office/calendar/1904/7") |> v2_response(200)

      assert calendar["year"] == 1904
      assert calendar["month"] == 7
      assert length(calendar["days"]) == 31

      dates = Enum.map(calendar["days"], &Date.from_iso8601!(&1["date"]))
      assert dates == Enum.sort(dates, Date)
    end

    test "an impossible month is a 400", %{conn: conn} do
      body = conn |> get_v2("/office/calendar/1904/13") |> v2_response(400)

      assert [%{"code" => "invalid_argument"}] = body["errors"]
    end
  end

  describe "GET /office/vocabulary" do
    test "lists the same slugs and defaults as GET /api/office/versions", %{conn: conn} do
      vocabulary = conn |> get_v2("/office/vocabulary") |> v2_response(200)
      v1 = conn |> get("/api/office/versions") |> json_response(200) |> Map.fetch!("data")

      assert Enum.map(vocabulary["hours"], & &1["slug"]) == Enum.map(v1["hours"], & &1["slug"])

      assert Enum.map(vocabulary["versions"], & &1["slug"]) ==
               Enum.map(v1["versions"], & &1["slug"])

      assert vocabulary["default_version"] == "rubrics-1960"
      assert vocabulary["default_language"] == "english"
    end
  end
end
