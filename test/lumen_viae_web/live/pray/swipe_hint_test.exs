defmodule LumenViaeWeb.Live.Pray.SwipeHintTest do
  @moduledoc """
  The one-time swipe hint, as the app's `PrayerSwipeHint`: in the page only
  when there is no player to move the beads. The SwipeHint hook decides
  whether this browser has seen it, and it starts hidden so a browser that
  has never runs nothing.

  The player is there whenever the Rosary has a recording to play, which
  takes AWS credentials to sign its URLs; the tests without them are the
  ones with nothing to play.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]
  import Phoenix.LiveViewTest

  test "with no player the hint is in the page, hidden and dismissible", %{conn: conn} do
    {:ok, view, html} = live(conn, "/mysteries/joyful/pray")

    refute has_element?(view, "[phx-hook=SpokenRosary]")
    assert has_element?(view, "#swipe-hint[phx-hook=SwipeHint]")
    assert has_element?(view, "#swipe-hint [data-hint][hidden]")
    assert has_element?(view, ~s(#swipe-hint button[data-dismiss][aria-label="Dismiss the hint"]))
    assert html =~ "Swipe left for the next bead"
  end

  test "the hint knows the bead, so moving one takes it away", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")
    assert has_element?(view, ~s(#swipe-hint[data-place="0-0"]))

    view |> element("button[phx-click=next]") |> render_click()
    assert has_element?(view, ~s(#swipe-hint[data-place="0-1"]))
  end

  test "old links that counted on a rosary open the same way", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?count=beads")

    assert has_element?(view, "#bead-0")
    assert has_element?(view, "#swipe-hint")
  end

  test "with the player the voice moves the beads, so there is no hint", %{conn: conn} do
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")

    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")

    assert has_element?(view, "[phx-hook=SpokenRosary]")
    refute has_element?(view, "#swipe-hint")
  end
end
