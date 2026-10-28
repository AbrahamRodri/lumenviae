defmodule LumenViaeWeb.Live.HomeScheduleTest do
  @moduledoc """
  Today's mysteries follow the schedule this browser chose, as the app's
  `MysterySchedule` setting: the traditional one, the server's default,
  or the modern one, where Thursday is Luminous and Saturday Joyful. The
  MysterySchedule hook keeps the choice and hands it back on connect.

  Like `LumenViaeWeb.Live.HomeTodayTest`, the tests move "today" to a
  chosen weekday with an offset of whole days.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp offset_to(day_of_week) do
    days_ahead = Integer.mod(day_of_week - Date.day_of_week(Date.utc_today()), 7)
    -days_ahead * 24 * 60
  end

  defp open_on(conn, day_of_week) do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "set_timezone", %{"offset" => offset_to(day_of_week)})
    view
  end

  defp devotion_heading(view), do: view |> element("#todays-devotion-heading") |> render()

  defp choose(view, schedule) do
    view
    |> element(~s(#mystery-schedule button[phx-value-schedule="#{schedule}"]))
    |> render_click()
  end

  test "the traditional schedule is chosen until the visitor chooses", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(
             view,
             ~s(#mystery-schedule[phx-hook=MysterySchedule][data-schedule="traditional"])
           )

    assert has_element?(
             view,
             ~s(#mystery-schedule button[phx-value-schedule="traditional"][aria-pressed="true"])
           )

    assert has_element?(
             view,
             ~s(#mystery-schedule button[phx-value-schedule="modern"][aria-pressed="false"])
           )
  end

  test "on the modern schedule Thursday is Luminous", %{conn: conn} do
    view = open_on(conn, 4)
    assert devotion_heading(view) =~ "Joyful"

    choose(view, "modern")

    assert devotion_heading(view) =~ "Luminous"
    assert has_element?(view, ~s(#pray-today[href="/mysteries/luminous"]))
    assert_push_event(view, "store_schedule", %{schedule: "modern"})
  end

  test "on the modern schedule Saturday is Joyful", %{conn: conn} do
    view = open_on(conn, 6)
    assert devotion_heading(view) =~ "Glorious"

    choose(view, "modern")
    assert devotion_heading(view) =~ "Joyful"
  end

  test "the two schedules agree on the other days", %{conn: conn} do
    view = open_on(conn, 2)
    choose(view, "modern")
    assert devotion_heading(view) =~ "Sorrowful"
  end

  test "the week of beads follows the schedule", %{conn: conn} do
    view = open_on(conn, 1)
    choose(view, "modern")
    html = render(view)

    assert html =~ "Thursday: the Luminous Mysteries"
    assert html =~ "Saturday: the Joyful Mysteries"
  end

  test "choosing the traditional schedule again goes back", %{conn: conn} do
    view = open_on(conn, 4)
    choose(view, "modern")
    choose(view, "traditional")

    assert devotion_heading(view) =~ "Joyful"
    assert_push_event(view, "store_schedule", %{schedule: "traditional"})
  end

  test "the schedule saved in this browser is restored, without saving it again", %{conn: conn} do
    view = open_on(conn, 4)
    render_hook(view, "restore_schedule", %{"schedule" => "modern"})

    assert devotion_heading(view) =~ "Luminous"
    assert has_element?(view, ~s(#mystery-schedule[data-schedule="modern"]))
    refute_push_event(view, "store_schedule", %{})
  end

  test "an unknown schedule is ignored", %{conn: conn} do
    view = open_on(conn, 4)

    render_hook(view, "restore_schedule", %{"schedule" => "monastic"})
    render_click(view, "set_schedule", %{"schedule" => "monastic"})
    render_hook(view, "restore_schedule", %{})

    assert devotion_heading(view) =~ "Joyful"
  end

  test "the timezone and the schedule may arrive in either order", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "restore_schedule", %{"schedule" => "modern"})
    render_hook(view, "set_timezone", %{"offset" => offset_to(4)})

    assert devotion_heading(view) =~ "Luminous"
  end
end
