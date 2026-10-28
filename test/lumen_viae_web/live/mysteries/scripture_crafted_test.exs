defmodule LumenViaeWeb.Live.Mysteries.ScriptureCraftedTest do
  @moduledoc "The Scripture page's tabs ignore a crafted event rather than crash."
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "a tab event without an id is ignored", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries")

    render_click(view, "select-category", %{})
    render_click(view, "select-category", %{"id" => "nonsense"})

    assert has_element?(view, ~s([role=tab][aria-selected="true"]))
  end
end
