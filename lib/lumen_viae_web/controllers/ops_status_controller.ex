defmodule LumenViaeWeb.OpsStatusController do
  @moduledoc """
  `GET /ops/status`: `LumenViae.Ops.status/0` for whoever holds the token
  in `OPS_STATUS_TOKEN`, sent as `authorization: Bearer <token>`.

  Without the variable set the route answers 404, as if it were not there,
  and so does a missing or wrong token: nothing tells a stranger it
  exists. `bin/prod-feature-check` reads it when given the token.
  """
  use LumenViaeWeb, :controller

  def show(conn, _params) do
    if authorized?(conn) do
      conn
      |> put_resp_header("cache-control", "no-store")
      |> json(LumenViae.Ops.status())
    else
      conn |> put_status(:not_found) |> json(%{error: %{code: "not_found", message: "Not found"}})
    end
  end

  defp authorized?(conn) do
    with token when is_binary(token) and token != "" <-
           Application.get_env(:lumen_viae, :ops_status_token),
         ["Bearer " <> given] <- get_req_header(conn, "authorization") do
      Plug.Crypto.secure_compare(given, token)
    else
      _no -> false
    end
  end
end
