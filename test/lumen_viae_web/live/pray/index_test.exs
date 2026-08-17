defmodule LumenViaeWeb.Live.Pray.IndexTest do
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias LumenViae.Curation.CsvImport
  alias LumenViae.Rosary

  # CSV in, rendered page out: proves the whole import-to-display path never
  # leaks pause markers or break tags into what the user sees.
  test "imported pause markers never reach the rendered meditation", %{conn: conn} do
    {:ok, _mystery} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1})

    marked_content =
      "First paragraph of the meditation. {pause:1.5} Same paragraph continues.\n\n" <>
        "{pause:2.5}\n\nSecond paragraph of the meditation."

    csv =
      "mystery_name,content,set_name,set_category\n" <>
        "The Annunciation,\"#{marked_content}\",Round Trip Set,joyful"

    assert [{:ok, _}] = CsvImport.import_string(csv, skip_audio: true)

    set = Rosary.get_meditation_set_by_name("Round Trip Set")

    {:ok, _view, html} = live(conn, "/meditation-sets/#{set.id}/pray")

    assert html =~ "First paragraph of the meditation. Same paragraph continues."
    assert html =~ "Second paragraph of the meditation."

    refute html =~ "{pause"
    refute html =~ "pause:"
    refute html =~ "<break"
    refute html =~ "&lt;break"
  end
end
