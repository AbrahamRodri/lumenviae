defmodule LumenViaeWeb.API.OfficeControllerTest do
  @moduledoc """
  The Office endpoints end to end: route, controller, context, parser,
  serializer - everything but the wire to the engine, which Req.Test
  answers with saved pages.

  The office cache is shared across the suite, so these tests keep to
  dates in the 1900s that no other test file uses.
  """
  use LumenViaeWeb.ConnCase, async: true

  # A cache of this test's own, so no other test's entries answer for it.
  setup do
    LumenViae.Office.Cache.isolate()
    :ok
  end

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

  # The app decodes these as Optional<String>.
  defp assert_cell(nil, _where), do: :ok

  defp assert_cell(cell, where) when is_map(cell) do
    assert is_list(cell["lines"]), "#{where} lines must be a list, never null"
    assert Enum.all?(cell["lines"], &is_binary/1), "#{where} lines must all be strings"
    assert_string_or_nil(cell["title"], "#{where} title")
    assert_string_or_nil(cell["note"], "#{where} note")
  end

  defp assert_day_entry(day) do
    assert is_binary(day["date"]) and day["date"] =~ ~r/^\d{4}-\d{2}-\d{2}$/

    case day["celebration"] do
      nil ->
        :ok

      celebration when is_map(celebration) ->
        assert is_binary(celebration["title"])
        assert_string_or_nil(celebration["rank"], "celebration rank")
    end

    case day["detail"] do
      nil ->
        :ok

      detail when is_map(detail) ->
        assert_string_or_nil(detail["label"], "detail label")
        assert_string_or_nil(detail["text"], "detail text")
    end

    assert_string_or_nil(day["note"], "note")
    assert_string_or_nil(day["letter"], "letter")
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

    # O1: one null `lines` or one non-string line fails the whole hour for
    # the app, so every section is checked, both sides.
    test "every section is typed the way the app decodes it", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      sections =
        conn
        |> get(~p"/api/office/1902-03-04/laudes")
        |> json_response(200)
        |> get_in(["data", "sections"])

      assert sections != []

      for {section, index} <- Enum.with_index(sections) do
        assert_cell(section["latin"], "section #{index} latin")
        assert_cell(section["vernacular"], "section #{index} vernacular")
      end
    end

    # G2: URLSession's default Accept.
    test "answers */* with 200 JSON", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      assert conn
             |> Plug.Conn.put_req_header("accept", "*/*")
             |> get(~p"/api/office/1902-03-05/laudes")
             |> json_response(200)
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

    # O2
    test "the day entry is typed the way the app decodes it", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      data = conn |> get(~p"/api/office/1902-05-24") |> json_response(200) |> Map.fetch!("data")

      assert_day_entry(data)
    end

    # O3: as on the hour route, so the app's URLCache may keep it.
    test "a success may be cached publicly", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      conn = get(conn, ~p"/api/office/1902-05-25")

      assert response(conn, 200)
      assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
    end

    # G2
    test "answers */* with 200 JSON", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      assert conn
             |> Plug.Conn.put_req_header("accept", "*/*")
             |> get(~p"/api/office/1902-05-26")
             |> json_response(200)
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

    # O2
    test "every day of the month is typed and in ascending date order", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      days =
        conn
        |> get(~p"/api/office/calendar/1902/7")
        |> json_response(200)
        |> get_in(["data", "days"])

      assert days != []
      Enum.each(days, &assert_day_entry/1)
      assert Enum.map(days, & &1["date"]) == days |> Enum.map(& &1["date"]) |> Enum.sort()
    end

    # O3
    test "a success may be cached publicly", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      conn = get(conn, ~p"/api/office/calendar/1902/8")

      assert response(conn, 200)
      assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
    end

    # G2
    test "answers */* with 200 JSON", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      assert conn
             |> Plug.Conn.put_req_header("accept", "*/*")
             |> get(~p"/api/office/calendar/1902/9")
             |> json_response(200)
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

    # G2
    test "answers */* with 200 JSON", %{conn: conn} do
      assert conn
             |> Plug.Conn.put_req_header("accept", "*/*")
             |> get(~p"/api/office/versions")
             |> json_response(200)
    end
  end
end
