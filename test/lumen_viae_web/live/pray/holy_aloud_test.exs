defmodule LumenViaeWeb.Live.Pray.HolyAloudTest do
  @moduledoc """
  Every way of praying the page is the app's simple Rosary: the player says
  the whole Rosary, a prayer at a time on the screen, and the old links
  that chose to count on a rosary or to pray in silence open the same page.
  The voice never starts on arrival, since a browser allows sound only
  after a tap; it is told to play only when the reader's own action brings
  the player.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]
  import Phoenix.LiveViewTest

  @holy "/mysteries/joyful/pray?form=holy"

  # The player is built from recordings, whose URLs need credentials to
  # sign; these are local arithmetic and never reach AWS.
  setup do
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")
    :ok
  end

  test "the Audio Rosary opens with the player, a bead at a time", %{conn: conn} do
    {:ok, view, _html} = live(conn, @holy)

    assert has_element?(view, "[phx-hook=SpokenRosary]")
    assert has_element?(view, "#bead-0")
    refute has_element?(view, "button[phx-click=toggle_pray_aloud]")
  end

  test "it waits for a tap rather than playing on arrival", %{conn: conn} do
    {:ok, view, _html} = live(conn, @holy)
    refute_push_event(view, "spoken_play", %{})
  end

  test "every form opens with the player, a bead at a time", %{conn: conn} do
    for path <- ["/mysteries/joyful/pray", "/mysteries/sorrowful/pray?form=scriptural"] do
      {:ok, view, _html} = live(conn, path)

      assert has_element?(view, "[phx-hook=SpokenRosary]")
      assert has_element?(view, "#bead-0")
    end
  end

  test "old links that said otherwise open the same page, and the next URL drops them",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, "#{@holy}&aloud=false&count=beads")

    assert has_element?(view, "[phx-hook=SpokenRosary]")
    assert has_element?(view, "#bead-0")
    refute has_element?(view, "button[phx-click=toggle_pray_aloud]")

    view |> element("button[phx-click=next]") |> render_click()
    assert_patch(view, "/mysteries/joyful/pray?mystery=opening&step=1&form=holy")
  end

  test "moving on keeps the URL short", %{conn: conn} do
    {:ok, view, _html} = live(conn, @holy)

    view |> element("button[phx-click=next]") |> render_click()
    assert_patch(view, "/mysteries/joyful/pray?mystery=opening&step=1&form=holy")
  end

  test "choosing the Audio Rosary brings its form, and plays", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")

    render_click(view, "set_form", %{"form" => "holy"})
    assert_patch(view, "/mysteries/joyful/pray?mystery=opening&step=0&form=holy")
    assert has_element?(view, "[phx-hook=SpokenRosary]")
    assert_push_event(view, "spoken_play", %{})
  end

  test "a closing prayer chosen while praying plays the new player", %{conn: conn} do
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
