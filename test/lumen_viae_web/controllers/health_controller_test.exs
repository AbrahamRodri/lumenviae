defmodule LumenViaeWeb.HealthControllerTest do
  @moduledoc """
  `GET /healthz` is public, so the test that matters most is the one that
  says what it does not say: three keys and nothing more.
  """
  use LumenViaeWeb.ConnCase, async: true

  test "answers 200 with the status, the release's version and the database", %{conn: conn} do
    conn = get(conn, "/healthz")

    assert json_response(conn, 200) == %{
             "status" => "ok",
             "version" => to_string(Application.spec(:lumen_viae, :vsn)),
             "db" => "ok"
           }

    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end

  test "needs no session, no admin and no canonical host", %{conn: conn} do
    conn = conn |> Map.put(:host, "203.0.113.7") |> get("/healthz")
    assert conn.status == 200
  end

  test "is not under /api, whose v1 is a contract with installed builds", %{conn: conn} do
    assert conn |> get("/api/healthz") |> Map.get(:status) == 404
  end
end
