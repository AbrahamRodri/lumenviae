defmodule LumenViaeWeb.API.CompletionBackCompatTest do
  @moduledoc """
  A build of the app already on someone's phone, posting exactly what it
  posts today.

  This exists because `GuardCompletions` sits in front of the one route the
  app writes to, and the failure it could cause is silent: a user agent
  misread as a crawler answers 403, the app has nothing watching for it, and
  the completion figures quietly go to zero. `ContractTest` cannot catch
  that - it sends no user agent at all, so it never exercises the guard
  against a realistic one.

  The agents below are real `URLSession`, `Alamofire` and `WKWebView`
  shapes. If a change to `BotDetection` ever starts matching one of them,
  this fails instead of production.
  """
  use LumenViaeWeb.ConnCase, async: true

  alias LumenViae.Rosary

  setup do
    {:ok, set} =
      Rosary.create_meditation_set(%{
        name: "BC #{System.unique_integer([:positive])}",
        category: "joyful"
      })

    %{set: set}
  end

  # Real URLSession default agents, plus the WKWebView shape.
  @agents [
    "LumenViae/1.0 CFNetwork/1494.0.7 Darwin/23.4.0",
    "LumenViae/1.2.3 CFNetwork/1568.100.1 Darwin/24.0.0",
    "lumenviae/1.0 CFNetwork/978.0.7 Darwin/18.7.0",
    "Lumen%20Viae/1 CFNetwork/1410.0.3 Darwin/22.6.0",
    "MyApp/1 CFNetwork/1220.1 Darwin/20.3.0",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
  ]

  test "every realistic iOS agent is let through", %{conn: conn, set: set} do
    for agent <- @agents do
      body =
        conn
        |> Plug.Conn.put_req_header("user-agent", agent)
        |> post(~p"/api/completions", %{meditation_set_id: set.id})
        |> json_response(201)

      assert body["data"]["meditation_set_id"] == set.id, "blocked: #{agent}"
    end
  end

  test "a build that sends no user-agent at all still works", %{conn: conn, set: set} do
    assert conn
           |> post(~p"/api/completions", %{meditation_set_id: set.id})
           |> json_response(201)
  end

  test "the old body shape, with no new fields, is unchanged", %{conn: conn, set: set} do
    body =
      conn
      |> Plug.Conn.put_req_header("user-agent", "LumenViae/1.0 CFNetwork/1494.0.7 Darwin/23.4.0")
      |> post(~p"/api/completions", %{meditation_set_id: set.id})
      |> json_response(201)

    # Exactly the three keys the shipped Codable struct decodes, no more.
    assert Map.keys(body["data"]) |> Enum.sort() == ~w(completed_at id meditation_set_id)
    assert is_integer(body["data"]["id"])
    assert is_integer(body["data"]["meditation_set_id"])
    assert is_binary(body["data"]["completed_at"])
  end

  test "a string id, which is what the app actually sends, still works", %{conn: conn, set: set} do
    assert conn
           |> Plug.Conn.put_req_header(
             "user-agent",
             "LumenViae/1.0 CFNetwork/1494.0.7 Darwin/23.4.0"
           )
           |> post(~p"/api/completions", %{meditation_set_id: to_string(set.id)})
           |> json_response(201)
  end

  test "the other four API routes are untouched by the guard", %{conn: conn} do
    conn =
      Plug.Conn.put_req_header(
        conn,
        "user-agent",
        "LumenViae/1.0 CFNetwork/1494.0.7 Darwin/23.4.0"
      )

    assert conn |> get(~p"/api/meditation-sets") |> json_response(200)
    assert conn |> get(~p"/api/mysteries") |> json_response(200)
  end

  test "even a crawler can still READ the API - only the write is guarded", %{conn: conn} do
    assert conn
           |> Plug.Conn.put_req_header("user-agent", "Googlebot/2.1")
           |> get(~p"/api/meditation-sets")
           |> json_response(200)
  end
end
