defmodule LumenViaeWeb.RedirectControllerTest do
  use LumenViaeWeb.ConnCase, async: true

  # The pages retired to archive/ are still linked from bookmarks and
  # search results, so each address sends the reader home for good.
  for path <- ~w(/dashboard /rosary-methods /saint-carlo /feedback) do
    test "#{path} redirects home permanently", %{conn: conn} do
      conn = get(conn, unquote(path))

      assert conn.status == 301
      assert redirected_to(conn, 301) == "/"
    end
  end

  # The book came back to the site: its old address opens it.
  test "/true-devotion no longer redirects; it is the book", %{conn: conn} do
    conn = get(conn, "/true-devotion")

    assert conn.status == 200
  end
end
