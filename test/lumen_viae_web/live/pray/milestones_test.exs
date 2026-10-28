defmodule LumenViaeWeb.Live.Pray.MilestonesTest do
  @moduledoc """
  The completion screen carries the app's devotional milestones, worded as
  its `StreakMilestone`, every one hidden. The streak is this browser's
  alone, so the PrayerStreak hook decides which one, if any, to show: the
  one the count has just reached, on the day's first Rosary.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp complete(conn) do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?mystery=closing")
    view |> element("button[phx-click=complete]") |> render_click()
    view
  end

  test "every milestone is on the completion screen, hidden", %{conn: conn} do
    doc = conn |> complete() |> render() |> Floki.parse_document!()
    cards = Floki.find(doc, "#prayer-milestones [data-milestone]")

    assert Enum.map(cards, &(&1 |> Floki.attribute("data-milestone") |> hd())) ==
             ~w(3 7 9 33 54 100 365)

    for card <- cards, do: assert(Floki.attribute(card, "hidden") != [])
  end

  test "each milestone is worded as the app words it", %{conn: conn} do
    html = conn |> complete() |> render()

    assert html =~ "Milestone reached"
    assert html =~ "9 days"

    assert html =~
             "Nine days in a row: a novena, as the Apostles prayed for nine days before Pentecost."

    assert html =~
             "Thirty-three days, as long as St. Louis de Montfort&#39;s Consecration to Mary."

    assert html =~
             "The great Rosary novena complete: 27 days asking, and 27 giving thanks."

    assert html =~ "A full year of daily prayer, for the greater glory of God."
  end

  test "the streak hook is on the completion screen with its milestones", %{conn: conn} do
    view = complete(conn)

    assert has_element?(view, "#prayer-complete[phx-hook=PrayerStreak] #prayer-milestones")
    assert has_element?(view, "#prayer-streak[data-streak]")
  end
end
