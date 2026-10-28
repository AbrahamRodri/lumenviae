defmodule LumenViaeWeb.OpsStatusControllerTest do
  @moduledoc """
  `GET /ops/status` is there only for whoever holds `OPS_STATUS_TOKEN`; to
  everybody else, and on a machine without the variable, it does not exist.
  Not async: the token is application config.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  @token "a-long-random-token"

  defp bearer(conn, token), do: put_req_header(conn, "authorization", "Bearer " <> token)

  test "is not there without OPS_STATUS_TOKEN set, token or no token", %{conn: conn} do
    put_env(:lumen_viae, :ops_status_token, nil)

    assert conn |> get("/ops/status") |> json_response(404)
    assert build_conn() |> bearer(@token) |> get("/ops/status") |> json_response(404)
  end

  test "is not there for a missing or wrong token", %{conn: conn} do
    put_env(:lumen_viae, :ops_status_token, @token)

    assert conn |> get("/ops/status") |> json_response(404)
    assert build_conn() |> bearer("wrong") |> get("/ops/status") |> json_response(404)
  end

  test "answers the release, the checks and the queues for the right token", %{conn: conn} do
    put_env(:lumen_viae, :ops_status_token, @token)

    conn = conn |> bearer(@token) |> get("/ops/status")
    status = json_response(conn, 200)

    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert Map.keys(status) |> Enum.sort() == ~w(checks commit jobs recent_failures version)

    assert Map.keys(status["checks"]) |> Enum.sort() ==
             ~w(database elevenlabs geolocation office_engine s3 s3_signing)

    assert status["checks"]["database"]["status"] == "ok"
    # The test machine has no AWS keys.
    assert status["checks"]["s3_signing"] == %{"status" => "off", "detail" => "no credentials"}

    for queue <- status["jobs"] do
      assert Map.keys(queue) |> Enum.sort() ==
               ~w(available cancelled discarded executing queue retryable scheduled)
    end
  end
end
