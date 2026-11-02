defmodule LumenViaeWeb.HomeLiveTest do
  use LumenViaeWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "The Rosary, Illuminated"
  end

  test "every public page offers the app through Safari's Smart App Banner", %{conn: conn} do
    for path <- [~p"/", ~p"/mysteries", ~p"/prayers", ~p"/privacy-policy"] do
      html = conn |> get(path) |> html_response(200)
      assert html =~ ~s(<meta name="apple-itunes-app" content="app-id=6760320749">)
    end
  end
end
