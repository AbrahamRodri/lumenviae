defmodule LumenViaeWeb.ClientIPHeaderTest do
  @moduledoc """
  `CLIENT_IP_HEADER` names the one header `LumenViaeWeb.ClientIP` trusts:
  Fly's by default, Caddy's `X-Real-IP` on the VM in `deploy/vm/`. Not
  async: the header is application config.
  """
  use ExUnit.Case, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViaeWeb.ClientIP

  defp conn_with(headers) do
    Enum.reduce(headers, %{Plug.Test.conn(:post, "/") | remote_ip: {10, 0, 0, 2}}, fn {k, v},
                                                                                      conn ->
      Plug.Conn.put_req_header(conn, k, v)
    end)
  end

  test "behind Caddy, reads the header Caddy writes, and no longer Fly's" do
    put_env(:lumen_viae, :client_ip_header, "X-Real-IP")

    conn = conn_with([{"x-real-ip", "203.0.113.7"}, {"fly-client-ip", "198.51.100.1"}])
    assert ClientIP.from_conn(conn) == "203.0.113.7"

    # A Fly header a caller sends to the VM is only a header: the peer stands.
    assert ClientIP.from_conn(conn_with([{"fly-client-ip", "198.51.100.1"}])) == "10.0.0.2"
  end

  test "unset, it is Fly's, as it always was" do
    put_env(:lumen_viae, :client_ip_header, "fly-client-ip")

    assert ClientIP.from_conn(conn_with([{"fly-client-ip", "203.0.113.7"}])) == "203.0.113.7"
    assert ClientIP.from_conn(conn_with([{"x-real-ip", "203.0.113.7"}])) == "10.0.0.2"
  end
end
