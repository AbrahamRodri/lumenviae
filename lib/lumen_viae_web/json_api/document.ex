defmodule LumenViaeWeb.JsonApi.Document do
  @moduledoc """
  Serves `GET /api/v2/open_api`: the committed `priv/openapi/v2.json`, read
  once when this module compiles, rather than the document AshJsonApi would
  generate on every request.

  The two are the same document: `open_api_test.exs` fails when the
  generated one differs from the file, so serving the file serves what the
  routes describe, without spending CPU on it for anyone who asks. The file
  is an external resource, so a regenerated document recompiles this
  module.
  """
  @behaviour Plug

  import Plug.Conn

  @path Path.expand("../../../priv/openapi/v2.json", __DIR__)
  @external_resource @path
  @document File.read!(@path)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, @document)
    |> halt()
  end
end
