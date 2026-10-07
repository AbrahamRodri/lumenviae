defmodule LumenViaeWeb.Live.Pray.IndexTest do
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias LumenViae.Curation.CsvImport
  alias LumenViae.Rosary

  # CSV in, rendered page out: proves the whole import-to-display path never
  # leaks pause markers or break tags into what the user sees.
  test "imported pause markers never reach the rendered meditation", %{conn: conn} do
    {:ok, _mystery} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1},
        actor: admin()
      )

    marked_content =
      "First paragraph of the meditation. {pause:1.5} Same paragraph continues.\n\n" <>
        "{pause:2.5}\n\nSecond paragraph of the meditation."

    csv =
      "mystery_name,content,set_name,set_category\n" <>
        "The Annunciation,\"#{marked_content}\",Round Trip Set,joyful"

    assert [{:ok, _}] = CsvImport.import_string(csv, skip_audio: true, actor: admin())

    set = Rosary.get_meditation_set_by_name("Round Trip Set", nil, actor: admin())

    {:ok, _view, html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=0")

    assert html =~ "First paragraph of the meditation. Same paragraph continues."
    assert html =~ "Second paragraph of the meditation."

    refute html =~ "{pause"
    refute html =~ "pause:"
    refute html =~ "<break"
    refute html =~ "&lt;break"
  end

  # An empty set is a hidden set. The page used to redirect home with a
  # flash the public layout never showed; it now answers as it does for any
  # set the public cannot see.
  test "a set with no meditations is a 404, like any hidden set", %{conn: conn} do
    {:ok, set} =
      Rosary.create_meditation_set(%{name: "Not filled yet", category: "joyful"}, actor: admin())

    assert_error_sent :not_found, fn -> get(conn, "/meditation-sets/#{set.id}/pray") end
  end
end
