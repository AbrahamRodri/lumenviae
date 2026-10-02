defmodule LumenViaeWeb.Plugs.ThrottleSignInTest do
  @moduledoc """
  The sign-in throttle on its own, with its limits passed in, so it can run
  alongside the rest of the suite. Each test signs in from its own address
  and email, so no two tests share a counter.
  """
  use LumenViaeWeb.ConnCase, async: true

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

  test "lets anything but a POST to the sign-in route through" do
    conn =
      build_conn(:get, "/admin/login")
      |> init_test_session(%{})
      |> fetch_flash()
      |> ThrottleSignIn.call(per_ip: 0, per_email: 0)

    refute conn.halted
  end
end
