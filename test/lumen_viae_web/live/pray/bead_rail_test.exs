defmodule LumenViaeWeb.Live.Pray.BeadRailTest do
  @moduledoc """
  The bead rail beside the words, as the app's: about five beads of a
  decade around the one under the hand, with its Hail Mary's number; the
  pendant's beads and cross for the opening prayers; the medal for the
  closing prayers.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @path "/mysteries/joyful/pray"

  defp beads(view),
    do: view |> render() |> Floki.parse_document!() |> Floki.find("#bead-rail [data-bead]")

  defp ids(view), do: Enum.flat_map(beads(view), &Floki.attribute(&1, "data-bead"))

  defp current(view),
    do:
      view |> render() |> Floki.parse_document!() |> Floki.find("#bead-rail [data-state=current]")

  test "the opening prayers show the pendant, the cross at the foot", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)

    assert ids(view) == ~w(chain small_bead_3 small_bead_2 small_bead_1 large_bead cross)
    assert has_element?(view, "#bead-rail[aria-hidden=true]")
    assert has_element?(view, "#bead-rail [data-bead=cross][data-state=current]")
  end

  test "the closing prayers show the medal alone", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path <> "?mystery=closing")

    assert ids(view) == ["medal"]
  end

  test "a decade shows five beads around the one under the hand", %{conn: conn} do
    # The announcement sits on the decade's first bead.
    {:ok, view, _html} = live(conn, @path <> "?mystery=0&step=0")
    assert ids(view) == ~w(decade-0 decade-1 decade-2 decade-3 decade-4)
    assert has_element?(view, "#bead-rail [data-bead=decade-0][data-state=current]")

    # A Hail Mary is in the middle of its five, with its number beside it.
    {:ok, view, _html} = live(conn, @path <> "?mystery=0&step=6")
    [bead] = current(view)
    [id] = Floki.attribute(bead, "data-bead")
    "decade-" <> n = id
    n = String.to_integer(n)

    assert n in 3..8
    assert length(ids(view)) == 5
    assert Enum.at(ids(view), 2) == id
    assert Floki.text(bead) =~ Integer.to_string(n)
    assert has_element?(view, "#bead-rail [data-bead=decade-#{n - 1}][data-state=said]")
    assert has_element?(view, "#bead-rail [data-bead=decade-#{n + 1}][data-state=to_come]")
  end
end
