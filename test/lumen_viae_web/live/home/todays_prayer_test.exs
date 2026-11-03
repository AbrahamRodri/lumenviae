defmodule LumenViaeWeb.Live.Home.TodaysPrayerTest do
  @moduledoc """
  Today's Prayer on the home page, the app's TodaysPrayerSection: the
  Consecration's row from the plan the browser keeps, the hour's order of
  prayer and the Hours of Prayer from the browser's clock, each a frame
  until its source has spoken. The rules are tested over fixed dates and
  hours; the page over what the hooks hand it.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Home.TodaysPrayer

  @today ~D[2026-11-02]

  defp data, do: TodaysPrayer.load(nil)

  defp plan(start, completed_at \\ nil),
    do: %{start: start, feast_id: nil, completed_at: completed_at}

  describe "the Consecration's row" do
    test "with no plan, invites one" do
      row = TodaysPrayer.consecration(data(), nil, [], @today, nil)

      assert row.name == "Consecration to Mary"
      assert row.subtitle == "Give yourself to Jesus through Mary"
      assert row.fact == "Begin"
      assert row.path == "/consecration"
      assert {"glorious_coronation", _x, _y} = row.painting
      refute row.prayed?
    end

    test "chosen ahead, says the day it begins" do
      row = TodaysPrayer.consecration(data(), plan(~D[2026-11-21]), [], @today, nil)

      assert row.fact == "Begins Nov 21"
      assert row.spoken =~ "Begins Saturday, November 21"
      assert row.path == "/consecration"
    end

    test "under way, today's day with its title, phase painting and seal once prayed" do
      start = Date.add(@today, -14)
      row = TodaysPrayer.consecration(data(), plan(start), [14], @today, nil)

      assert row.fact == "Day 15 of 33"
      assert row.subtitle == "Dying to Self"
      assert row.path == "/consecration/days/15"
      assert {"sorrowful_agony", _x, _y} = row.painting
      refute row.prayed?

      assert TodaysPrayer.consecration(data(), plan(start), [15], @today, nil).prayed?
    end

    test "Day 34 is the day of consecration; past it, ready, never late" do
      day34 = TodaysPrayer.consecration(data(), plan(Date.add(@today, -33)), [], @today, nil)
      assert day34.fact == "The day of consecration"
      assert day34.subtitle == "Total Consecration"
      assert day34.path == "/consecration/days/34"

      later = TodaysPrayer.consecration(data(), plan(Date.add(@today, -40)), [], @today, nil)
      assert later.fact == "Ready to consecrate"
      assert later.path == "/consecration/days/34"
    end

    test "made today keeps its seal; made earlier invites a new one" do
      made = plan(Date.add(@today, -33), "2026-11-02T15:00:00Z")

      today = TodaysPrayer.consecration(data(), made, [34], @today, @today)
      assert today.fact == "Consecrated today"
      assert today.prayed?

      earlier = TodaysPrayer.consecration(data(), made, [34], @today, Date.add(@today, -3))
      assert earlier.fact == "Begin"
      refute earlier.prayed?
    end
  end

  describe "the hours' rows" do
    test "the hour's order, said when it is said" do
      morning = TodaysPrayer.hour_order(data(), ~N[2026-11-02 07:30:00])
      assert morning.name == "Morning Prayers"
      assert morning.subtitle == "Giving the day to God."
      assert morning.fact == "On waking"
      assert morning.path == "/prayers/orders/morning"

      noon = TodaysPrayer.hour_order(data(), ~N[2026-11-02 12:00:00])
      assert noon.fact == "At noon"
      assert noon.path == "/prayers/orders/angelus"
      assert TodaysPrayer.hour_order(data(), ~N[2026-11-02 16:00:00]).fact == "At 6 PM"

      night = TodaysPrayer.hour_order(data(), ~N[2026-11-02 02:00:00])
      assert night.fact == "At bedtime"
      assert night.path == "/prayers/orders/night"
    end

    test "the Angelus is Queen of Heaven in Eastertide" do
      row = TodaysPrayer.hour_order(data(), ~N[2026-04-10 12:00:00])
      assert row.name =~ "Queen of Heaven"
      assert row.subtitle == "The Easter prayer to Mary, said in place of the Angelus."
    end

    test "the Hours of Prayer: the hour now and until when" do
      row = TodaysPrayer.office(~N[2026-11-02 10:15:00])

      assert row.subtitle == "Mid-Morning Prayer (Terce)"
      assert row.fact == "Now · until noon"
      assert row.mark == :lit_hour
      assert row.path == "/hours"
      assert TodaysPrayer.office(~N[2026-11-02 23:00:00]).fact == "Now · until midnight"
    end

    test "the date line and the next turn" do
      assert TodaysPrayer.date_line(@today) == "MON 2 NOV"
      assert TodaysPrayer.next_turn_in(~N[2026-11-02 10:59:30]) == 30_000
      assert TodaysPrayer.next_turn_in(~N[2026-11-02 23:00:00]) == 3_600_000
    end
  end

  describe "on the home page" do
    defp state(plan, done \\ [], today \\ Date.utc_today()) do
      %{"plan" => plan, "done" => done, "intro_seen" => false, "today" => Date.to_iso8601(today)}
    end

    test "waits as frames until the browser speaks", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Today&#39;s Prayer"
      assert has_element?(view, "#todays-prayer[phx-hook=ConsecrationPlan]")
      assert view |> element("#todays-prayer") |> render() |> count("data-role=\"waiting\"") == 3
      refute has_element?(view, "[data-role=todays-prayer-date]")
    end

    test "shows the rows and their links once the plan and the clock are known", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_hook(view, "set_timezone", %{"offset" => 0})
      render_hook(view, "consecration_state", state(nil))

      refute has_element?(view, "#todays-prayer [data-role=waiting]")
      assert has_element?(view, "[data-role=row-consecration][href='/consecration']", "Begin")
      assert has_element?(view, "[data-role=row-hour_order][href^='/prayers/orders/']")
      assert has_element?(view, "[data-role=row-office][href='/hours']", "Now · until")
      refute has_element?(view, "[data-role=row-mass]")

      date = TodaysPrayer.date_line(Date.utc_today())
      assert has_element?(view, "[data-role=todays-prayer-date]", date)
    end

    test "a plan under way opens today's day, marked once prayed", %{conn: conn} do
      start = Date.add(Date.utc_today(), -4)
      plan = %{"start" => Date.to_iso8601(start), "feast_id" => nil, "completed_at" => nil}

      {:ok, view, _html} = live(conn, "/")
      render_hook(view, "consecration_state", state(plan, [5]))

      assert has_element?(
               view,
               "[data-role=row-consecration][href='/consecration/days/5'][data-prayed=true]",
               "Day 5 of 33"
             )

      assert has_element?(view, "[data-role=prayed-seal]")
    end

    test "an Act made on the browser's today reads as consecrated today", %{conn: conn} do
      today = Date.utc_today()
      start = Date.add(today, -33)

      plan = %{
        "start" => Date.to_iso8601(start),
        "feast_id" => nil,
        "completed_at" => DateTime.to_iso8601(DateTime.utc_now())
      }

      {:ok, view, _html} = live(conn, "/")

      render_hook(
        view,
        "consecration_state",
        Map.put(state(plan, [34]), "completed_on", Date.to_iso8601(today))
      )

      assert has_element?(view, "[data-role=row-consecration]", "Consecrated today")

      render_hook(
        view,
        "consecration_state",
        Map.put(state(plan, [34]), "completed_on", Date.to_iso8601(Date.add(today, -1)))
      )

      assert has_element?(view, "[data-role=row-consecration]", "Begin")
    end
  end

  defp count(html, needle), do: html |> String.split(needle) |> length() |> Kernel.-(1)
end
