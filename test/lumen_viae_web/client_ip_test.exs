defmodule LumenViaeWeb.ClientIPTest do
  @moduledoc """
  The header precedence here is a security boundary, not a preference: the
  leftmost `X-Forwarded-For` entry is caller-supplied, so reading it would
  let anyone choose which address their completions are attributed to and
  which rate-limit bucket they spend.
  """
  use ExUnit.Case, async: true

  alias LumenViaeWeb.ClientIP

  defp conn_with(headers, remote_ip \\ {127, 0, 0, 1}) do
    Enum.reduce(headers, %{Plug.Test.conn(:post, "/") | remote_ip: remote_ip}, fn {k, v}, conn ->
      Plug.Conn.put_req_header(conn, k, v)
    end)
  end

  describe "from_conn/1" do
    test "prefers Fly's own header, which the proxy sets and overwrites" do
      conn = conn_with([{"fly-client-ip", "203.0.113.7"}, {"x-forwarded-for", "8.8.8.8"}])

      assert ClientIP.from_conn(conn) == "203.0.113.7"
    end

    test "takes the rightmost forwarded entry, not the spoofable leftmost one" do
      # What a caller sending `X-Forwarded-For: 8.8.8.8` produces once Fly
      # has appended the address it actually came from.
      conn = conn_with([{"x-forwarded-for", "8.8.8.8, 203.0.113.7"}])

      assert ClientIP.from_conn(conn) == "203.0.113.7"
    end

    test "a forged chain cannot push the real address out of reach" do
      conn = conn_with([{"x-forwarded-for", "1.1.1.1, 2.2.2.2, 3.3.3.3, 203.0.113.7"}])

      assert ClientIP.from_conn(conn) == "203.0.113.7"
    end

    test "falls back to the socket peer when nothing is in front of the app" do
      assert conn_with([], {198, 51, 100, 9}) |> ClientIP.from_conn() == "198.51.100.9"
    end

    test "ignores blank header values rather than returning an empty string" do
      conn = conn_with([{"fly-client-ip", "   "}], {198, 51, 100, 9})

      assert ClientIP.from_conn(conn) == "198.51.100.9"
    end
  end

  describe "from_connect_info/2" do
    test "reads the forwarded header a LiveView socket is given" do
      headers = [{"x-forwarded-for", "8.8.8.8, 203.0.113.7"}]

      assert ClientIP.from_connect_info(headers, %{address: {127, 0, 0, 1}}) == "203.0.113.7"
    end

    test "falls back to peer data" do
      assert ClientIP.from_connect_info([], %{address: {198, 51, 100, 9}}) == "198.51.100.9"
    end

    test "answers nil on a disconnected mount, where there is no connect info" do
      assert ClientIP.from_connect_info(nil, nil) == nil
    end
  end
end
