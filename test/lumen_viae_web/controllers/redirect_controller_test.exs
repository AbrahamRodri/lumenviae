defmodule LumenViaeWeb.RedirectControllerTest do
  use LumenViaeWeb.ConnCase, async: true

  # The pages retired to archive/ are still linked from bookmarks and
  # search results, so each address sends the reader home for good.
  for path <- ~w(/dashboard /app /rosary-methods /true-devotion /saint-carlo /feedback) do
    test "#{path} redirects home permanently", %{conn: conn} do
      conn = get(conn, unquote(path))

      assert conn.status == 301
      assert redirected_to(conn, 301) == "/"
    end
  end
end
