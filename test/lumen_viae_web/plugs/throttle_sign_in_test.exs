defmodule LumenViaeWeb.Plugs.ThrottleSignInTest do
  @moduledoc """
  The sign-in throttle on its own, with its limits passed in, so it can run
  alongside the rest of the suite. Each test signs in from its own address
  and email, so no two tests share a counter.
  """
  use LumenViaeWeb.ConnCase, async: true

  alias LumenViae.Test.Addresses
  alias LumenViaeWeb.Plugs.ThrottleSignIn

  @sign_in "/admin/auth/admin/password/sign_in"

  defp unique, do: System.unique_integer([:positive])

  defp ip, do: "198.51.#{rem(unique(), 250)}.#{rem(unique(), 250)}"

  defp attempt(ip, email, opts) do
    build_conn(:post, @sign_in, %{"admin" => %{"email" => email, "password" => "x"}})
    |> Map.put(:remote_ip, ip |> String.to_charlist() |> :inet.parse_address() |> elem(1))
    |> init_test_session(%{})
    |> fetch_flash()
    |> ThrottleSignIn.call(opts)
  end

  test "refuses the attempt after the per-address limit, whatever the email" do
    ip = "203.0.113.#{rem(unique(), 250)}"
    opts = [per_ip: 3, per_email: 1_000]
    salt = unique()

    for n <- 1..3 do
      refute attempt(ip, "a#{n}-#{salt}@lumenviae.test", opts).halted
    end

    conn = attempt(ip, "a4-#{salt}@lumenviae.test", opts)
    assert conn.halted
    assert redirected_to(conn) == "/admin/login"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Too many sign-in attempts"
  end

  test "refuses the attempt after the per-email limit, from any address" do
    email = "target-#{unique()}@lumenviae.test"
    opts = [per_ip: 1_000, per_email: 2]

    refute attempt(ip(), email, opts).halted
    refute attempt(ip(), email, opts).halted
    assert attempt(ip(), email, opts).halted
  end

  test "counts the email without regard to case or surrounding space" do
    email = "case-#{unique()}@lumenviae.test"
    opts = [per_ip: 1_000, per_email: 1]

    refute attempt(ip(), email, opts).halted
    assert attempt(ip(), "  " <> String.upcase(email) <> " ", opts).halted
  end

  test "one address over its limit does not hold up another" do
    opts = [per_ip: 1, per_email: 1_000]
    busy = "192.0.2.#{rem(unique(), 250)}"
    salt = unique()

    refute attempt(busy, "b1-#{salt}@lumenviae.test", opts).halted
    assert attempt(busy, "b2-#{salt}@lumenviae.test", opts).halted
    refute attempt("198.18.#{rem(unique(), 250)}.1", "b3-#{salt}@lumenviae.test", opts).halted
  end

  test "counts an IPv6 caller by its /64, so changing the address buys no budget" do
    opts = [per_ip: 2, per_email: 1_000]
    network = Addresses.unique_ipv6_network()
    salt = unique()

    refute attempt(network <> "::1", "v6a-#{salt}@lumenviae.test", opts).halted
    refute attempt(network <> "::2", "v6b-#{salt}@lumenviae.test", opts).halted

    # A third address in the same /64, as privacy extensions would present.
    conn = attempt(network <> ":aaaa:bbbb:cccc:dddd", "v6c-#{salt}@lumenviae.test", opts)
    assert conn.halted
    assert redirected_to(conn) == "/admin/login"
  end

  test "one IPv6 /64 over its limit does not hold up another" do
    opts = [per_ip: 1, per_email: 1_000]
    busy = Addresses.unique_ipv6_network()
    salt = unique()

    refute attempt(busy <> "::1", "v6d-#{salt}@lumenviae.test", opts).halted
    assert attempt(busy <> "::2", "v6e-#{salt}@lumenviae.test", opts).halted

    refute attempt(Addresses.unique_ipv6_network() <> "::1", "v6f-#{salt}@lumenviae.test", opts).halted
  end

  test "still counts an IPv4 caller by its whole address" do
    opts = [per_ip: 1, per_email: 1_000]
    salt = unique()
    ip = Addresses.unique_ip()

    refute attempt(ip, "v4a-#{salt}@lumenviae.test", opts).halted
    assert attempt(ip, "v4b-#{salt}@lumenviae.test", opts).halted
    refute attempt(Addresses.unique_ip(), "v4c-#{salt}@lumenviae.test", opts).halted
  end

  test "lets anything but a POST to the sign-in route through" do
    conn =
      build_conn(:get, "/admin/login")
      |> init_test_session(%{})
      |> fetch_flash()
      |> ThrottleSignIn.call(per_ip: 0, per_email: 0)

    refute conn.halted
  end
end
