defmodule LumenViaeWeb.JsonApiHelpers do
  @moduledoc """
  Calls `/api/v2` the way a JSON:API client does: through the router and
  the `:json_api` pipeline, with the JSON:API media type on the request.
  """
  import Phoenix.ConnTest
  import Plug.Conn

  @endpoint LumenViaeWeb.Endpoint

  @media_type "application/vnd.api+json"

  @doc "GETs `path` under `/api/v2` and returns the conn."
  def get_v2(conn, path) do
    conn
    |> put_req_header("accept", @media_type)
    |> get("/api/v2" <> path)
  end

  @doc "POSTs `body` as JSON to `path` under `/api/v2` and returns the conn."
  def post_v2(conn, path, body) do
    conn
    |> put_req_header("accept", @media_type)
    |> put_req_header("content-type", @media_type)
    |> post("/api/v2" <> path, Jason.encode!(body))
  end

  @doc "The decoded body, asserting the status and the JSON:API media type."
  def v2_response(conn, status) do
    assert_media_type!(conn)
    conn |> response(status) |> Jason.decode!()
  end

  defp assert_media_type!(conn) do
    [content_type] = get_resp_header(conn, "content-type")

    unless String.starts_with?(content_type, @media_type) do
      raise "expected #{@media_type}, got #{content_type}"
    end
  end
end
