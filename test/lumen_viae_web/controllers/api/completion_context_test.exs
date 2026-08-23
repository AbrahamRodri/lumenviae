defmodule LumenViaeWeb.API.CompletionContextTest do
  @moduledoc """
  What the iOS app reports with a completion, and how little of it is
  required.

  Every field here is optional on purpose. Builds of the app already in the
  wild send none of them, and must keep working exactly as they do now.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completions.Completion

  @app_agent "LumenViae/1.2 CFNetwork/1494.0.7 Darwin/23.4.0"

  setup %{conn: conn} do
    {:ok, set} =
      Rosary.create_meditation_set(%{
        name: "API ctx #{System.unique_integer([:positive])}",
        category: "joyful"
      })

    %{set: set, conn: Plug.Conn.put_req_header(conn, "user-agent", @app_agent)}
  end

  defp last_completion, do: Repo.one(from c in Completion, order_by: [desc: c.id], limit: 1)

  test "a completion from the app is recorded as coming from the app", %{conn: conn, set: set} do
    assert conn
           |> post(~p"/api/completions", %{meditation_set_id: set.id})
           |> json_response(201)

    assert last_completion().source == "ios"
  end

  test "the timezone and locale the app sends are kept", %{conn: conn, set: set} do
    assert conn
           |> post(~p"/api/completions", %{
             meditation_set_id: set.id,
             time_zone: "America/Chicago",
             locale: "en-US"
           })
           |> json_response(201)

    completion = last_completion()

    assert completion.time_zone == "America/Chicago"
    assert completion.locale == "en-US"
  end

  test "an older build that sends neither still records a completion", %{conn: conn, set: set} do
    assert conn
           |> post(~p"/api/completions", %{meditation_set_id: set.id})
           |> json_response(201)

    completion = last_completion()

    assert completion.time_zone == nil
    assert completion.locale == nil
  end

  test "a field of the wrong type is dropped, not allowed to fail the completion",
       %{conn: conn, set: set} do
    assert conn
           |> post(~p"/api/completions", %{
             meditation_set_id: set.id,
             time_zone: 12_345,
             locale: %{"unexpected" => true}
           })
           |> json_response(201)

    completion = last_completion()

    assert completion.time_zone == nil
    assert completion.locale == nil
  end

  test "a blank string is stored as nothing rather than as an empty place",
       %{conn: conn, set: set} do
    assert conn
           |> post(~p"/api/completions", %{meditation_set_id: set.id, time_zone: "   "})
           |> json_response(201)

    assert last_completion().time_zone == nil
  end

  test "the address is truncated before it is stored", %{conn: conn, set: set} do
    assert conn
           |> Plug.Conn.put_req_header("fly-client-ip", "203.0.113.99")
           |> post(~p"/api/completions", %{meditation_set_id: set.id})
           |> json_response(201)

    assert last_completion().ip_prefix == "203.0.113.0"
  end

  test "the response still carries only the keys the shipped app decodes",
       %{conn: conn, set: set} do
    body =
      conn
      |> post(~p"/api/completions", %{meditation_set_id: set.id})
      |> json_response(201)

    assert Map.keys(body["data"]) |> Enum.sort() == ~w(completed_at id meditation_set_id)
  end
end
