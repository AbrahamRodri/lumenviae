defmodule LumenViaeWeb.Graphql.OfficeTest do
  @moduledoc """
  The Divine Office over GraphQL, end to end: router, pipeline, schema,
  the Breviary resource and the Office domain beneath it - everything but
  the wire to the engine, which Req.Test answers with saved pages.

  The office cache is shared across the suite, so these tests keep to
  dates in 1903, which no other test file uses (the REST Office tests keep to 1901 and 1902).
  """
  use LumenViaeWeb.ConnCase, async: true

  # A cache of this test's own, so no other test's entries answer for it.
  setup do
    LumenViae.Office.Cache.isolate()
    :ok
  end

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Office.DivinumOfficium

  @fixtures Path.expand("../../support/fixtures/divinum_officium", __DIR__)

  @hour_query """
  query Hour($date: Date!, $hour: String!, $version: String, $language: String) {
    officeHour(date: $date, hour: $hour, version: $version, language: $language) {
      date hour version language tempora
      celebration { title rank }
      sections {
        latin { title note lines }
        vernacular { title note lines }
      }
      source { name url }
    }
  }
  """

  defp stub_page(name) do
    html = File.read!(Path.join(@fixtures, name))
    test_pid = self()

    Req.Test.stub(DivinumOfficium, fn conn ->
      send(test_pid, {:asked, conn.params})
      Req.Test.html(conn, html)
    end)
  end

  describe "officeHour" do
    test "answers the hour in the same words as the REST API", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      assert %{"data" => %{"officeHour" => hour}} =
               graphql(conn, @hour_query, %{date: "1903-03-04", hour: "laudes"})

      assert hour["date"] == "1903-03-04"
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

    test "every cell has a list of lines, never null", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      %{"data" => %{"officeHour" => hour}} =
        graphql(conn, @hour_query, %{date: "1903-03-05", hour: "laudes"})

      for section <- hour["sections"], cell <- [section["latin"], section["vernacular"]], cell do
        assert is_list(cell["lines"])
        assert Enum.all?(cell["lines"], &is_binary/1)
      end
    end

    test "passes version and language through to the engine", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      graphql(conn, @hour_query, %{
        date: "1903-03-06",
        hour: "laudes",
        version: "tridentine-1570",
        language: "latin"
      })

      assert_received {:asked, params}
      assert params["version"] == "Tridentine - 1570"
      assert params["lang2"] == "Latin"
    end

    test "an unknown hour is an invalid_argument error naming the valid hours", %{conn: conn} do
      body = graphql(conn, @hour_query, %{date: "1903-03-07", hour: "brunch"})

      # Nullable at the root: the field is null and its error says why.
      assert body["data"] == %{"officeHour" => nil}
      assert [%{"code" => "invalid_argument", "message" => message}] = body["errors"]
      assert message =~ "unknown hour"
      assert message =~ "completorium"
    end

    test "a date outside the engine's window is a bad_request error", %{conn: conn} do
      body = graphql(conn, @hour_query, %{date: "1492-10-12", hour: "laudes"})

      assert [%{"code" => "invalid_argument", "message" => message}] = body["errors"]
      assert message =~ "between 1600 and 2200"
    end

    test "engine trouble is an office_unavailable error the client can retry", %{conn: conn} do
      Req.Test.stub(DivinumOfficium, fn conn -> Req.Test.transport_error(conn, :timeout) end)

      body = graphql(conn, @hour_query, %{date: "1903-03-08", hour: "laudes"})

      assert [%{"code" => "office_unavailable"}] = body["errors"]
    end
  end

  describe "officeHours" do
    test "answers all eight hours of a date in liturgical order", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      query = """
      query Hours($date: Date!) {
        officeHours(date: $date) { hour date }
      }
      """

      %{"data" => %{"officeHours" => hours}} = graphql(conn, query, %{date: "1903-04-01"})

      assert Enum.map(hours, & &1["hour"]) ==
               ~w(matutinum laudes prima tertia sexta nona vesperae completorium)

      assert Enum.all?(hours, &(&1["date"] == "1903-04-01"))
    end
  end

  describe "officeDay" do
    test "answers the day's calendar entry", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      query = """
      query Day($date: Date!) {
        officeDay(date: $date) {
          date note letter
          celebration { title rank }
          detail { label text }
        }
      }
      """

      %{"data" => %{"officeDay" => day}} = graphql(conn, query, %{date: "1903-05-24"})

      assert day["date"] == "1903-05-24"

      assert day["celebration"] == %{
               "title" => "S. Bartholomæi Apostoli",
               "rank" => "II. classis"
             }

      assert day["detail"]["label"] == "Tempora"
    end
  end

  describe "officeCalendar" do
    @calendar_query """
    query Month($year: Int!, $month: Int!) {
      officeCalendar(year: $year, month: $month) {
        year month version
        days { date celebration { title rank } }
      }
    }
    """

    test "answers the month, its days in date order", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      %{"data" => %{"officeCalendar" => calendar}} =
        graphql(conn, @calendar_query, %{year: 1903, month: 7})

      assert calendar["year"] == 1903
      assert calendar["month"] == 7
      assert calendar["version"] == "rubrics-1960"
      assert length(calendar["days"]) == 31

      dates = Enum.map(calendar["days"], &Date.from_iso8601!(&1["date"]))
      assert dates == Enum.sort(dates, Date)
      assert hd(dates) == ~D[1903-07-01]
    end

    test "an impossible month is a bad_request error", %{conn: conn} do
      body = graphql(conn, @calendar_query, %{year: 1903, month: 13})

      assert [%{"code" => "invalid_argument"}] = body["errors"]
    end
  end

  describe "officeVocabulary" do
    test "lists the same slugs and defaults as GET /api/office/versions", %{conn: conn} do
      query = """
      {
        officeVocabulary {
          defaultVersion defaultLanguage
          versions { slug label }
          hours { slug label }
          languages { slug label }
        }
      }
      """

      %{"data" => %{"officeVocabulary" => vocabulary}} = graphql(conn, query)

      assert vocabulary["defaultVersion"] == "rubrics-1960"
      assert vocabulary["defaultLanguage"] == "english"

      assert Enum.map(vocabulary["hours"], & &1["slug"]) ==
               ~w(matutinum laudes prima tertia sexta nona vesperae completorium)

      assert Enum.any?(vocabulary["versions"], &(&1["slug"] == "rubrics-1960"))
      assert Enum.any?(vocabulary["languages"], &(&1["slug"] == "english"))
    end
  end

  describe "the HTTP layer" do
    test "every response is private and uncacheable", %{conn: conn} do
      conn = post_graphql(conn, "{ officeVocabulary { defaultVersion } }")

      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
    end

    test "a client sending accept */* is answered", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "*/*")
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/graphql",
          Jason.encode!(%{query: "{ officeVocabulary { defaultVersion } }"})
        )

      assert %{"data" => %{"officeVocabulary" => _}} = json_response(conn, 200)
    end

    test "an over-complex query is refused before it runs", %{conn: conn} do
      aliases =
        Enum.map_join(1..300, "\n", fn n -> "v#{n}: officeVocabulary { defaultVersion }" end)

      body = graphql(conn, "{ #{aliases} }")

      assert body["data"] == nil
      assert [%{"code" => "too_complex"} | _] = body["errors"]
    end
  end

  describe "error codes" do
    test "one failing field leaves its siblings their data", %{conn: conn} do
      body =
        graphql(conn, """
        {
          officeVocabulary { defaultVersion }
          officeHour(date: "1903-08-01", hour: "brunch") { hour }
        }
        """)

      assert body["data"]["officeVocabulary"]["defaultVersion"] == "rubrics-1960"
      assert body["data"]["officeHour"] == nil
      assert [%{"code" => "invalid_argument", "path" => ["officeHour"]}] = body["errors"]
    end

    test "a document that cannot run is invalid_document", %{conn: conn} do
      body = graphql(conn, "{ officeVocabulary { noSuchField } }")

      assert [%{"code" => "invalid_document"}] = body["errors"]
    end
  end

  describe "the upstream budget" do
    # No stub in these tests: a refused document must not reach the engine,
    # and one that does reach it would fail loudly on the missing stub.

    test "refuses a document that aliases officeHours past the budget", %{conn: conn} do
      aliases =
        Enum.map_join(1..4, "\n", fn n ->
          "h#{n}: officeHours(date: \"1903-06-0#{n}\") { hour }"
        end)

      body = graphql(conn, "{ #{aliases} }")

      assert body["data"] == nil
      assert [%{"code" => "over_budget", "message" => message}] = body["errors"]
      assert message =~ "32 Divine Office fetches"
    end

    test "counts fields reached through fragments", %{conn: conn} do
      query = """
      query {
        ...Days
        ... on RootQueryType { c: officeHours(date: "1903-06-03") { hour } }
      }
      fragment Days on RootQueryType {
        a: officeHours(date: "1903-06-01") { hour }
        b: officeHours(date: "1903-06-02") { hour }
        d: officeHours(date: "1903-06-04") { hour }
      }
      """

      body = graphql(conn, query)

      assert body["data"] == nil
      assert [%{"code" => "over_budget", "message" => message}] = body["errors"]
      assert message =~ "32 Divine Office fetches"
    end

    test "lets through the app's heaviest real request, two days of hours", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      query = """
      query {
        today: officeHours(date: "1903-06-10") { hour }
        tomorrow: officeHours(date: "1903-06-11") { hour }
      }
      """

      %{"data" => data} = graphql(conn, query)

      assert length(data["today"]) == 8
      assert length(data["tomorrow"]) == 8
    end
  end
end
