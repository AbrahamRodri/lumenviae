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

  describe "behind Cloudflare (CLIENT_IP_CLOUDFLARE)" do
    # 172.70.1.2 lies in Cloudflare's 172.64.0.0/13; 198.51.100.9 lies in none.
    @edge "172.70.1.2"

    setup do
      put_env(:lumen_viae, :client_ip_header, "fly-client-ip")
      :ok
    end

    test "off, as by default, CF-Connecting-IP is just a header" do
      put_env(:lumen_viae, :client_ip_cloudflare, false)

      conn = conn_with([{"fly-client-ip", @edge}, {"cf-connecting-ip", "203.0.113.7"}])
      assert ClientIP.from_conn(conn) == @edge
    end

    test "on, a request from Cloudflare's edge is the visitor it carried" do
      put_env(:lumen_viae, :client_ip_cloudflare, true)

      conn = conn_with([{"fly-client-ip", @edge}, {"cf-connecting-ip", "203.0.113.7"}])
      assert ClientIP.from_conn(conn) == "203.0.113.7"

      ipv6 =
        conn_with([
          {"fly-client-ip", "2606:4700:10::ac43:1"},
          {"cf-connecting-ip", "2001:db8::1"}
        ])

      assert ClientIP.from_conn(ipv6) == "2001:db8::1"
    end

    test "on, a caller who reaches the origin directly cannot choose their address" do
      put_env(:lumen_viae, :client_ip_cloudflare, true)

      forged = conn_with([{"fly-client-ip", "198.51.100.9"}, {"cf-connecting-ip", "203.0.113.7"}])
      assert ClientIP.from_conn(forged) == "198.51.100.9"
    end

    test "on, an edge request without the header, or with a blank one, keeps the edge address" do
      put_env(:lumen_viae, :client_ip_cloudflare, true)

      assert ClientIP.from_conn(conn_with([{"fly-client-ip", @edge}])) == @edge

      blank = conn_with([{"fly-client-ip", @edge}, {"cf-connecting-ip", " "}])
      assert ClientIP.from_conn(blank) == @edge
    end

    test "on, the peer counts when no proxy header is set, as on a VM behind Cloudflare" do
      put_env(:lumen_viae, :client_ip_cloudflare, true)

      conn =
        %{Plug.Test.conn(:get, "/") | remote_ip: {172, 70, 1, 2}}
        |> Plug.Conn.put_req_header("cf-connecting-ip", "203.0.113.7")

      assert ClientIP.from_conn(conn) == "203.0.113.7"
    end

    test "the LiveView path reads what the HTTP request put in the session" do
      put_env(:lumen_viae, :client_ip_cloudflare, true)

      conn =
        [{"fly-client-ip", @edge}, {"cf-connecting-ip", "203.0.113.7"}]
        |> conn_with()
        |> Plug.Test.init_test_session(%{})
        |> LumenViaeWeb.Plugs.PutClientIP.call([])

      assert ClientIP.from_session(Plug.Conn.get_session(conn)) == "203.0.113.7"
    end
  end
end
