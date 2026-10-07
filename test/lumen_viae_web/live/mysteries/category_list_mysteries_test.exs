defmodule LumenViaeWeb.Live.Mysteries.CategoryListMysteriesTest do
  @moduledoc """
  The category page's list of mysteries, read from the mysteries table.
  Not async: a mystery's (category, order) is unique, and these tests need
  the real positions, which concurrent tests inserting the same key could
  deadlock on.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  test "lists each mystery with the fruit it is prayed for", %{conn: conn} do
    {:ok, _} =
      Rosary.create_mystery(
        %{name: "The Annunciation", category: "joyful", order: 1, fruit: "Humility"},
        actor: admin()
      )

    {:ok, view, html} = live(conn, "/mysteries/joyful")

    assert has_element?(view, "#mysteries-heading + ol li", "The Annunciation")
    assert html =~ "Fruit: Humility"
    # A position the table has no mystery for keeps its label.
    assert html =~ "The Fifth Joyful Mystery"
  end

  test "a set's fixture mysteries, outside the category's positions, are not listed",
       %{conn: conn} do
    {:ok, _} =
      Rosary.create_mystery(%{name: "Stray Fixture", category: "joyful", order: 1_001},
        actor: admin()
      )

    {:ok, _view, html} = live(conn, "/mysteries/joyful")

    refute html =~ "Stray Fixture"
  end
end
