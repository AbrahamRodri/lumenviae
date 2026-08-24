defmodule LumenViaeWeb.API.OfficeControllerTest do
  @moduledoc """
  The Office endpoints end to end: route, controller, context, parser,
  serializer - everything but the wire to the engine, which Req.Test
  answers with saved pages.

  The office cache is shared across the suite, so these tests keep to
  dates in the 1900s that no other test file uses.
  """
  use LumenViaeWeb.ConnCase, async: true

  alias LumenViae.Office.DivinumOfficium

  @fixtures Path.expand("../../../support/fixtures/divinum_officium", __DIR__)

  defp stub_page(name) do
    html = File.read!(Path.join(@fixtures, name))
    test_pid = self()

    Req.Test.stub(DivinumOfficium, fn conn ->
      send(test_pid, {:asked, conn.params})
      Req.Test.html(conn, html)
    end)
  end

  describe "GET /api/office/:date/:hour" do
    test "answers the hour as data", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      conn = get(conn, ~p"/api/office/1901-03-04/laudes")
      data = json_response(conn, 200)["data"]

      assert data["date"] == "1901-03-04"
      assert data["hour"] == "laudes"
      assert data["version"] == "rubrics-1960"
      assert data["language"] == "english"

      assert data["celebration"] == %{
               "title" => "S. Bartholomæi Apostoli",
               "rank" => "II. classis"
             }

      assert length(data["sections"]) == 11

      [incipit | _rest] = data["sections"]
      assert incipit["latin"]["title"] == "Incipit"
      assert incipit["vernacular"]["title"] == "Start"
      assert hd(incipit["latin"]["lines"]) == "℣. Deus ✠ in adiutórium meum inténde."

      assert data["source"]["name"] == "The Divinum Officium Project"
      assert data["source"]["url"] =~ "divinumofficium.com"
    end

    test "passes version and language through to the engine", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      conn =
        get(conn, ~p"/api/office/1901-03-05/laudes?version=tridentine-1570&language=latin")

      data = json_response(conn, 200)["data"]
      assert data["version"] == "tridentine-1570"
      assert data["language"] == "latin"

      assert_received {:asked, params}
      assert params["version"] == "Tridentine - 1570"
      assert params["lang2"] == "Latin"
      assert params["command"] == "prayLaudes"
    end

    test "a success may be cached publicly", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      conn = get(conn, ~p"/api/office/1901-03-06/laudes")

      assert response(conn, 200)
      assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
    end

    test "a date that is not a date is a 400 in the error envelope", %{conn: conn} do
      conn = get(conn, ~p"/api/office/tomorrow/laudes")

      assert %{"error" => %{"code" => "bad_request", "message" => message}} =
               json_response(conn, 400)

      assert message =~ "ISO 8601"
    end

    test "an unknown hour is a 400 naming the valid hours", %{conn: conn} do
      conn = get(conn, ~p"/api/office/1901-03-07/midnight")

      assert %{"error" => %{"code" => "bad_request", "message" => message}} =
               json_response(conn, 400)

      assert message =~ "vesperae"
    end

    test "engine trouble is a 503 the client can retry", %{conn: conn} do
      Req.Test.stub(DivinumOfficium, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      conn = get(conn, ~p"/api/office/1901-03-08/laudes")

      assert %{"error" => %{"code" => "office_unavailable"}} = json_response(conn, 503)
    end
  end

  describe "GET /api/office/:date" do
    test "answers the day's calendar entry", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      conn = get(conn, ~p"/api/office/1901-05-24")
      data = json_response(conn, 200)["data"]

      assert data["date"] == "1901-05-24"

      assert data["celebration"] == %{
               "title" => "S. Bartholomæi Apostoli",
               "rank" => "II. classis"
             }

      assert data["detail"]["label"] == "Tempora"
      assert data["version"] == "rubrics-1960"
    end
  end

  describe "GET /api/office/calendar/:year/:month" do
    test "answers the month", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      conn = get(conn, ~p"/api/office/calendar/1901/7")
      data = json_response(conn, 200)["data"]

      assert data["year"] == 1901
      assert data["month"] == 7
      assert length(data["days"]) == 31
      assert hd(data["days"])["date"] == "1901-07-01"
    end

    test "an impossible month is a 400", %{conn: conn} do
      conn = get(conn, ~p"/api/office/calendar/1901/13")

      assert %{"error" => %{"code" => "bad_request"}} = json_response(conn, 400)
    end
  end

  describe "GET /api/office/versions" do
    test "publishes the vocabulary and the defaults", %{conn: conn} do
      conn = get(conn, ~p"/api/office/versions")
      data = json_response(conn, 200)["data"]

      assert data["defaults"] == %{"version" => "rubrics-1960", "language" => "english"}

      assert %{"slug" => "rubrics-1960"} =
               Enum.find(data["versions"], &(&1["slug"] == "rubrics-1960"))

      assert Enum.map(data["hours"], & &1["slug"]) ==
               ~w(matutinum laudes prima tertia sexta nona vesperae completorium)

      assert Enum.any?(data["languages"], &(&1["slug"] == "english"))
    end
  end
end
