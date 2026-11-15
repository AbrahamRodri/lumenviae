defmodule LumenViaeWeb.Live.AccessibilityTest do
  @moduledoc """
  What a screen reader or a keyboard meets on the public pages (design's
  walk 3): ℣ and ℟ said as "Leader:" and "All:", the Rosary player's own
  skip link, and Home's week with an initial to fall back on at large text.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Components.Glyph

  describe "Glyph.markup/1" do
    test "℣ and ℟ are hidden from screen readers and said as Leader and All" do
      versicle = IO.iodata_to_binary(Glyph.markup("℣"))
      response = IO.iodata_to_binary(Glyph.markup("℟"))

      assert versicle =~ ~s(<span class="book-glyph" aria-hidden="true">℣</span>)
      assert versicle =~ ~s(<span class="sr-only">Leader: </span>)
      assert response =~ ~s(<span class="sr-only">All: </span>)
    end

    test "the stop after ℣ or ℟ is hidden with it, so nothing is read between" do
      runs = [{:glyph, "℣"}, {:text, ". The Angel"}, {:glyph, "✠"}, {:text, ". x"}]

      assert Glyph.with_stops(runs) ==
               [{:glyph, "℣."}, {:text, " The Angel"}, {:glyph, "✠"}, {:text, ". x"}]

      assert Glyph.with_stops([{:glyph, "℟"}, {:text, "."}]) == [{:glyph, "℟."}]

      assert IO.iodata_to_binary(Glyph.markup("℟.")) =~
               ~s(aria-hidden="true">℟.</span><span class="sr-only">All: </span>)
    end

    test "the cross is drawn as it is, with nothing added" do
      assert IO.iodata_to_binary(Glyph.markup("✠")) == ~s(<span class="book-glyph">✠</span>)
    end
  end

  test "a prayer's versicles and responses are read as Leader and All", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/prayers/angelus")

    assert html =~ ~s(<span class="sr-only">Leader: </span>)
    assert html =~ ~s(<span class="sr-only">All: </span>)
    refute html =~ ~s(<span class="book-glyph">℣</span>)
    refute html =~ ~s(<span class="sr-only">Leader: </span>.)
  end

  test "the Rosary player's first stop is its own skip link, to the prayer", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")

    assert view |> element("a.skip-link--own") |> render() =~ ~s(href="#prayer-main")
    assert has_element?(view, "#prayer-main[tabindex='-1']")
  end

  test "Home's week carries each day's initial beside its name", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, ".week-day .week-day__label", "Mon")
    assert has_element?(view, ".week-day .week-day__initial", "M")
  end

  test "a chant's Back pill carries a short Back to fall back on", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chant/adoro_te")

    assert has_element?(view, "a[data-role=back] .book-back__label")
    assert has_element?(view, "a[data-role=back] .book-back__short", "Back")
  end
end
