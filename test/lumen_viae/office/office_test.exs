defmodule LumenViae.OfficeTest do
  @moduledoc """
  The Office context against a stubbed engine.

  Async, because the Req.Test stub is owned per test process and nothing
  here touches global config. The cache is a shared named table that
  outlives a test, so every test that cares about fetch counts uses a
  date no other test uses.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Office
  alias LumenViae.Office.DivinumOfficium

  @fixtures Path.expand("../../support/fixtures/divinum_officium", __DIR__)

  defp fixture(name), do: File.read!(Path.join(@fixtures, name))

  defp stub_hour_page do
    html = fixture("laudes_2026-08-24.html")
    test_pid = self()

    Req.Test.stub(DivinumOfficium, fn conn ->
      send(test_pid, {:asked, conn.params})
      Req.Test.html(conn, html)
    end)
  end

  defp stub_kalendar_page do
    html = fixture("kalendar_2026-08.html")
    test_pid = self()

    Req.Test.stub(DivinumOfficium, fn conn ->
      send(test_pid, {:asked, conn.params})
      Req.Test.html(conn, html)
    end)
  end

  describe "fetch_hour/3" do
    test "assembles one hour from the engine's page" do
      stub_hour_page()

      assert {:ok, hour} = Office.fetch_hour("2026-08-24", "laudes")

      assert hour.date == ~D[2026-08-24]
      assert hour.hour == "laudes"
      assert hour.version == "rubrics-1960"
      assert hour.language == "english"
      assert hour.celebration.title == "S. Bartholomæi Apostoli"
      assert length(hour.sections) == 11
      assert hour.source_url =~ "divinumofficium.com"
      assert hour.source_url =~ "date1=08-24-2026"
    end

    test "speaks the engine's dialect on the wire" do
      stub_hour_page()

      Office.fetch_hour("2026-08-25", "vesperae", %{
        "version" => "divino-afflatu-1954",
        "language" => "deutsch"
      })

      assert_received {:asked, params}
      assert params["date1"] == "08-25-2026"
      assert params["command"] == "prayVesperae"
      assert params["version"] == "Divino Afflatu - 1954"
      assert params["lang2"] == "Deutsch"
    end

    test "asks the engine once per office, however many requests arrive" do
      stub_hour_page()

      for _ <- 1..3 do
        assert {:ok, _hour} = Office.fetch_hour("2026-02-11", "laudes")
      end

      assert_received {:asked, _params}
      refute_received {:asked, _params}
    end

    test "distinct languages are distinct cache entries" do
      stub_hour_page()

      assert {:ok, _} = Office.fetch_hour("2026-02-12", "laudes")
      assert {:ok, _} = Office.fetch_hour("2026-02-12", "laudes", %{"language" => "latin"})

      assert_received {:asked, _params}
      assert_received {:asked, _params}
    end

    test "an engine failure is 'unavailable', and is not cached" do
      test_pid = self()
      {:ok, agent} = Agent.start_link(fn -> :down end)
      html = fixture("laudes_2026-08-24.html")

      Req.Test.stub(DivinumOfficium, fn conn ->
        send(test_pid, :asked)

        case Agent.get(agent, & &1) do
          :down -> conn |> Plug.Conn.put_status(500) |> Req.Test.html("boom")
          :up -> Req.Test.html(conn, html)
        end
      end)

      assert Office.fetch_hour("2026-02-13", "laudes") == {:error, :office_unavailable}

      Agent.update(agent, fn _ -> :up end)
      assert {:ok, _hour} = Office.fetch_hour("2026-02-13", "laudes")

      assert_received :asked
      assert_received :asked
    end

    test "an unreachable engine is 'unavailable' rather than a crash" do
      Req.Test.stub(DivinumOfficium, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert Office.fetch_hour("2026-02-14", "laudes") == {:error, :office_unavailable}
    end

    test "a page the parser does not recognize is 'unavailable'" do
      Req.Test.stub(DivinumOfficium, fn conn ->
        Req.Test.html(conn, "<html><body>Down for maintenance</body></html>")
      end)

      assert Office.fetch_hour("2026-02-15", "laudes") == {:error, :office_unavailable}
    end

    test "rejects a date that is not a date" do
      assert {:error, {:bad_request, message}} = Office.fetch_hour("24-08-2026", "laudes")
      assert message =~ "ISO 8601"
    end

    test "rejects a date outside the engine's range" do
      assert {:error, {:bad_request, message}} = Office.fetch_hour("1234-01-01", "laudes")
      assert message =~ "between 1600 and 2200"
    end

    test "rejects an unknown hour, naming the valid ones" do
      assert {:error, {:bad_request, message}} = Office.fetch_hour("2026-08-24", "midnight")
      assert message =~ ~s(unknown hour "midnight")
      assert message =~ "matutinum"
      assert message =~ "completorium"
    end

    test "rejects an unknown version, naming the valid ones" do
      assert {:error, {:bad_request, message}} =
               Office.fetch_hour("2026-08-24", "laudes", %{"version" => "novus-ordo"})

      assert message =~ ~s(unknown version "novus-ordo")
      assert message =~ "rubrics-1960"
    end

    test "rejects an unknown language, naming the valid ones" do
      assert {:error, {:bad_request, message}} =
               Office.fetch_hour("2026-08-24", "laudes", %{"language" => "klingon"})

      assert message =~ ~s(unknown language "klingon")
      assert message =~ "english"
    end
  end

  describe "fetch_day/2" do
    test "finds the day in its month's calendar" do
      stub_kalendar_page()

      assert {:ok, day} = Office.fetch_day("2026-08-24")

      assert day.date == ~D[2026-08-24]
      assert day.celebration == %{title: "S. Bartholomæi Apostoli", rank: "II. classis"}
      assert day.version == "rubrics-1960"
    end

    test "one calendar fetch serves the whole month" do
      stub_kalendar_page()

      assert {:ok, _day} = Office.fetch_day("2026-05-03")
      assert {:ok, _day} = Office.fetch_day("2026-05-21")

      assert_received {:asked, params}
      assert params["kmonth"] == "5"
      assert params["kyear"] == "2026"
      assert params["version"] == "Rubrics 1960 - 1960"
      refute_received {:asked, _params}
    end
  end

  describe "fetch_calendar/3" do
    test "yields the month's days" do
      stub_kalendar_page()

      assert {:ok, calendar} = Office.fetch_calendar("2026", "8")

      assert calendar.year == 2026
      assert calendar.month == 8
      assert calendar.version == "rubrics-1960"
      assert length(calendar.days) == 31
    end

    test "rejects a month that is not one" do
      assert {:error, {:bad_request, message}} = Office.fetch_calendar("2026", "13")
      assert message =~ "between 1 and 12"
    end

    test "rejects a year outside the engine's range" do
      assert {:error, {:bad_request, message}} = Office.fetch_calendar("999", "8")
      assert message =~ "between 1600 and 2200"
    end
  end

  describe "vocabulary/0" do
    test "names the slugs and the defaults clients start from" do
      vocabulary = Office.vocabulary()

      assert vocabulary.defaults == %{version: "rubrics-1960", language: "english"}
      assert Enum.any?(vocabulary.versions, &(&1.slug == "divino-afflatu-1954"))
      assert Enum.map(vocabulary.hours, & &1.slug) |> hd() == "matutinum"
      assert Enum.any?(vocabulary.languages, &(&1.slug == "latin"))
    end
  end
end
