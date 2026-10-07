defmodule LumenViaeWeb.Live.Pray.SwipeHintTest do
  @moduledoc """
  The one-time swipe hint, as the app's `PrayerSwipeHint`: in the page only
  when counting on the screen and the voice is not moving the beads. The
  SwipeHint hook decides whether this browser has seen it, and it starts
  hidden so a browser that has never runs nothing.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "counting on the screen, the hint is in the page, hidden and dismissible", %{conn: conn} do
    {:ok, view, html} = live(conn, "/mysteries/joyful/pray?count=screen")

    assert has_element?(view, "#swipe-hint[phx-hook=SwipeHint]")
    assert has_element?(view, "#swipe-hint [data-hint][hidden]")
    assert has_element?(view, ~s(#swipe-hint button[data-dismiss][aria-label="Dismiss the hint"]))
    assert html =~ "Swipe left for the next bead"
  end

  test "the hint knows the bead, so moving one takes it away", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?count=screen")
    assert has_element?(view, ~s(#swipe-hint[data-place="0-0"]))

    view |> element("button[phx-click=next]") |> render_click()
    assert has_element?(view, ~s(#swipe-hint[data-place="0-1"]))
  end

  test "counting on a rosary there is nothing to swipe", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")
    refute has_element?(view, "#swipe-hint")
  end

  test "while praying aloud the voice moves the beads, so there is no hint", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?count=screen&aloud=true")
    refute has_element?(view, "#swipe-hint")
  end
end
