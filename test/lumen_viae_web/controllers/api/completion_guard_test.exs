defmodule LumenViaeWeb.API.CompletionGuardTest do
  @moduledoc """
  `POST /api/completions` is the only write the public API exposes, and the
  dashboard reads what it writes as fact. These are the two things standing
  in front of it.

  Not async, and not sharing a bucket with anything: the rate limit is a
  global counter keyed on address, so this file lowers the limit for its own
  duration and gives every test its own address to spend.
  """
  use LumenViaeWeb.ConnCase, async: false

  alias LumenViae.Rosary

  @limit 3

  setup do
    previous = Application.get_env(:lumen_viae, :completions_per_hour)
    Application.put_env(:lumen_viae, :completions_per_hour, @limit)
    on_exit(fn -> Application.put_env(:lumen_viae, :completions_per_hour, previous) end)

    {:ok, set} = Rosary.create_meditation_set(%{name: "Guarded", category: "joyful"})

    %{set: set}
  end

  # A fresh address per test, so one test's spending is never another's
  # failure.
  defp from_a_new_address(conn) do
    n = System.unique_integer([:positive])

    Plug.Conn.put_req_header(
      conn,
      "fly-client-ip",
      "203.0.#{rem(n, 200)}.#{rem(div(n, 200), 200)}"
    )
  end

  defp as(conn, agent), do: Plug.Conn.put_req_header(conn, "user-agent", agent)

  defp complete(conn, set), do: post(conn, ~p"/api/completions", %{meditation_set_id: set.id})

  describe "a crawler" do
    test "is refused, and records nothing", %{conn: conn, set: set} do
      before = Rosary.count_total_completions()

      body =
        conn
        |> from_a_new_address()
        |> as("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")
        |> complete(set)
        |> json_response(403)

      assert body["error"]["code"] == "automated_client"
      assert Rosary.count_total_completions() == before
    end

    test "so is a scripted client that names itself", %{conn: conn, set: set} do
      assert conn
             |> from_a_new_address()
             |> as("curl/8.4.0")
             |> complete(set)
             |> json_response(403)
    end
  end

  describe "a person" do
    test "is let through", %{conn: conn, set: set} do
      before = Rosary.count_total_completions()

      assert conn
             |> from_a_new_address()
             |> as("LumenViae/1.2 CFNetwork/1494.0.7 Darwin/23.4.0")
             |> complete(set)
             |> json_response(201)

      assert Rosary.count_total_completions() == before + 1
    end
  end

  describe "the rate limit" do
    test "allows the budget and then refuses, whatever the agent claims to be",
         %{conn: conn, set: set} do
      # The agent here is a plausible browser, which is the point: this is
      # the layer that still holds when the agent string is a lie.
      agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Version/17.2 Safari/605.1.15"
      ip = "198.51.100.#{rem(System.unique_integer([:positive]), 250)}"

      request = fn ->
        conn
        |> Plug.Conn.put_req_header("fly-client-ip", ip)
        |> as(agent)
        |> complete(set)
      end

      for _ <- 1..@limit do
        assert request.() |> json_response(201)
      end

      body = request.() |> json_response(429)
      assert body["error"]["code"] == "rate_limited"
    end

    test "one address running out does not affect another", %{conn: conn, set: set} do
      agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Version/17.2 Safari/605.1.15"
      spent = "198.51.101.#{rem(System.unique_integer([:positive]), 250)}"

      for _ <- 1..(@limit + 1) do
        conn |> Plug.Conn.put_req_header("fly-client-ip", spent) |> as(agent) |> complete(set)
      end

      assert conn |> from_a_new_address() |> as(agent) |> complete(set) |> json_response(201)
    end

    test "a forged forwarded header cannot buy a fresh budget", %{conn: conn, set: set} do
      agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Version/17.2 Safari/605.1.15"
      real = "198.51.102.#{rem(System.unique_integer([:positive]), 250)}"

      # The caller claims to be a different address each time; Fly appends
      # the one it actually came from on the right.
      request = fn claimed ->
        conn
        |> Plug.Conn.put_req_header("x-forwarded-for", "#{claimed}, #{real}")
        |> as(agent)
        |> complete(set)
      end

      for i <- 1..@limit do
        assert request.("9.9.9.#{i}") |> json_response(201)
      end

      assert request.("9.9.9.250") |> json_response(429)
    end
  end
end
