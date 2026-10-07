defmodule LumenViaeWeb.Live.Pray.HolyAloudTest do
  @moduledoc """
  The Rosary Said Aloud is, as the app prays it, the whole Rosary aloud
  with the beads on the screen: `form=holy` defaults to both, and a URL
  that says otherwise is followed. The voice never starts on arrival, since
  a browser allows sound only after a tap; it is told to play only when
  the reader's own action brings the player.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @holy "/mysteries/joyful/pray?form=holy"

  test "the Rosary Said Aloud opens aloud, counting on the screen", %{conn: conn} do
    {:ok, view, _html} = live(conn, @holy)

    assert has_element?(view, "[phx-hook=SpokenRosary]")
    assert has_element?(view, "#bead-0")
    assert has_element?(view, ~s(button[phx-click=toggle_pray_aloud][aria-pressed="true"]))
  end

  test "it waits for a tap rather than playing on arrival", %{conn: conn} do
    {:ok, view, _html} = live(conn, @holy)
    refute_push_event(view, "spoken_play", %{})
  end

  test "a URL that says otherwise is followed", %{conn: conn} do
    {:ok, view, _html} = live(conn, "#{@holy}&aloud=false")
    refute has_element?(view, "[phx-hook=SpokenRosary]")
    assert has_element?(view, "#bead-0")

    {:ok, view, _html} = live(conn, "#{@holy}&count=beads")
    assert has_element?(view, "[phx-hook=SpokenRosary]")
    refute has_element?(view, "#bead-0")
  end

  test "turning the voice off is written into the URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, @holy)

    view |> element("button[phx-click=toggle_pray_aloud]") |> render_click()
    assert_patch(view, "/mysteries/joyful/pray?mystery=opening&step=0&form=holy&aloud=false")
    refute has_element?(view, "[phx-hook=SpokenRosary]")
  end

  test "moving on keeps the URL short", %{conn: conn} do
    {:ok, view, _html} = live(conn, @holy)

    view |> element("button[phx-click=next]") |> render_click()
    assert_patch(view, "/mysteries/joyful/pray?mystery=opening&step=1&form=holy")
  end

  test "the other forms still open silent on the reader's own beads", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")

    refute has_element?(view, "[phx-hook=SpokenRosary]")
    refute has_element?(view, "#bead-0")
  end

  test "choosing the Rosary Said Aloud brings its way of praying, and plays", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")

    render_click(view, "set_form", %{"form" => "holy"})
    assert_patch(view, "/mysteries/joyful/pray?mystery=opening&step=0&form=holy")
    assert has_element?(view, "[phx-hook=SpokenRosary]")
    assert_push_event(view, "spoken_play", %{})
  end

  test "turning the voice on is the tap, so the player plays", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")

    view |> element("button[phx-click=toggle_pray_aloud]") |> render_click()
    assert_push_event(view, "spoken_play", %{})
  end

  test "a closing prayer chosen while praying aloud plays the new player", %{conn: conn} do
    {:ok, view, _html} = live(conn, @holy)

    render_click(view, "toggle_extra", %{"extra" => "memorare"})
    assert_push_event(view, "spoken_play", %{})
  end

  test "the closing prayers restored from this browser do not start the voice", %{conn: conn} do
    {:ok, view, _html} = live(conn, @holy)

    render_hook(view, "restore_extras", %{"extras" => ["memorare"]})
    refute_push_event(view, "spoken_play", %{})
  end
end
