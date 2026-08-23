defmodule LumenViaeWeb.ClientIPTest do
  @moduledoc """
  This file previously asserted that the rightmost `X-Forwarded-For` entry
  is the client. It is not, on this infrastructure: Fly appends its own
  address, and the first Rosary recorded in production was attributed to
  `2a09:8280:1::` - Fly's anycast range - and placed in Chicago.

  The tests below encode what replaced that: only headers whose meaning
  does not depend on the proxy layout are read.
  """
  use ExUnit.Case, async: true

  alias LumenViaeWeb.ClientIP

  defp conn_with(headers, remote_ip \\ {127, 0, 0, 1}) do
    Enum.reduce(headers, %{Plug.Test.conn(:post, "/") | remote_ip: remote_ip}, fn {k, v}, conn ->
      Plug.Conn.put_req_header(conn, k, v)
    end)
  end

  describe "from_conn/1" do
    test "uses Fly's own header, which the proxy sets and overwrites" do
      assert conn_with([{"fly-client-ip", "203.0.113.7"}]) |> ClientIP.from_conn() ==
               "203.0.113.7"
    end

    test "ignores X-Forwarded-For entirely, from either end" do
      # Reading the right of this gave Fly's proxy; reading the left takes
      # whatever the caller typed. Neither is used.
      conn = conn_with([{"x-forwarded-for", "8.8.8.8, 2a09:8280:1::"}], {198, 51, 100, 9})

      assert ClientIP.from_conn(conn) == "198.51.100.9"
    end

    test "a forged forwarded header cannot displace Fly's" do
      conn = conn_with([{"fly-client-ip", "203.0.113.7"}, {"x-forwarded-for", "8.8.8.8"}])

      assert ClientIP.from_conn(conn) == "203.0.113.7"
    end

    test "falls back to the socket peer when nothing is in front of the app" do
      assert conn_with([], {198, 51, 100, 9}) |> ClientIP.from_conn() == "198.51.100.9"
    end

    test "a blank Fly header falls through to the peer" do
      assert conn_with([{"fly-client-ip", "   "}], {198, 51, 100, 9}) |> ClientIP.from_conn() ==
               "198.51.100.9"
    end
  end

  describe "from_session/1" do
    test "reads the address the plug put there" do
      assert ClientIP.from_session(%{"client_ip" => "203.0.113.7"}) == "203.0.113.7"
    end

    test "answers nil when the session carries nothing" do
      assert ClientIP.from_session(%{}) == nil
      assert ClientIP.from_session(%{"client_ip" => ""}) == nil
      assert ClientIP.from_session(%{"client_ip" => nil}) == nil
    end
  end
end
