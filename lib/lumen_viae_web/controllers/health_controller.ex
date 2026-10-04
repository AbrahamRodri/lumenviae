defmodule LumenViaeWeb.HealthController do
  @moduledoc """
  `GET /healthz`: up, which release, and whether the database answers.

  For a load balancer, an uptime monitor or `Tools/dev doctor` in the iOS
  repo. At the root rather than under `/api`, whose v1 responses are a
  contract with installed iOS builds (docs/IOS_API_CONTRACT.md). No actor,
  no session and no authentication, so it says nothing that is not safe to
  say to anybody: `{"status", "version", "db"}`, 200 when the database
  answered and 503 when it did not. See `LumenViae.Ops.Health`.
  """
  use LumenViaeWeb, :controller

  def show(conn, _params) do
    health = LumenViae.Ops.health()

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_status(if health.status == "ok", do: :ok, else: :service_unavailable)
    |> json(health)
  end
end
