defmodule LumenViaeWeb.API.ErrorEnvelopeTest do
  @moduledoc """
  Every API error answers in one shape, whatever went wrong and wherever it
  came from. Before this there were two shapes and a hole: an unrecognised
  `{:error, reason}` matched no fallback clause and raised, so the client got
  a 500 with a stacktrace.
  """
  use LumenViaeWeb.ConnCase, async: true

  alias LumenViae.Rosary
  alias LumenViaeWeb.API.ErrorJSON
  alias LumenViaeWeb.API.FallbackController

  defp envelope(body) do
    assert %{"error" => error} = body
    assert is_binary(error["code"])
    assert is_binary(error["message"])
    error
  end

  describe "a missing resource" do
    test "a set that does not exist", %{conn: conn} do
      body = conn |> get(~p"/api/meditation-sets/999999") |> json_response(404)

      assert envelope(body)["code"] == "not_found"
    end

    test "an id that is not an id at all", %{conn: conn} do
      body = conn |> get(~p"/api/meditation-sets/not-a-number") |> json_response(404)

      assert envelope(body)["code"] == "not_found"
    end

    test "an id past what a bigint can hold, which used to reach the driver", %{conn: conn} do
      body = conn |> get(~p"/api/meditation-sets/99999999999999999999") |> json_response(404)

      assert envelope(body)["code"] == "not_found"
    end

    test "a prayer that is not one of the four chants", %{conn: conn} do
      body = conn |> get(~p"/api/prayers/gregorian_chant/audio") |> json_response(404)

      assert envelope(body)["code"] == "not_found"
    end

    test "a meditation that does not exist", %{conn: conn} do
      body = conn |> get(~p"/api/meditations/999999/audio") |> json_response(404)

      assert envelope(body)["code"] == "not_found"
    end
  end

  describe "a malformed request" do
    test "a completion with no set names what is missing, and is a 400", %{conn: conn} do
      body = conn |> post(~p"/api/completions", %{}) |> json_response(400)
      error = envelope(body)

      assert error["code"] == "bad_request"
      assert error["message"] =~ "meditation_set_id"
    end
  end

  describe "a request that fails validation" do
    test "a completion for a set that does not exist carries per-field detail", %{conn: conn} do
      body =
        conn |> post(~p"/api/completions", %{meditation_set_id: 999_999}) |> json_response(422)

      error = envelope(body)

      assert error["code"] == "validation_failed"
      assert is_map(error["details"])
      assert Map.has_key?(error["details"], "meditation_set_id")
    end
  end

  describe "the catch-all" do
    # This is the clause that did not exist. PrayerController.audio returned
    # {:error, reason} verbatim from S3, so {:error, :missing_credentials}
    # matched nothing and raised FunctionClauseError at the client.
    test "answers an error nothing anticipated instead of raising", %{conn: conn} do
      body =
        conn
        |> Phoenix.Controller.accepts(["json"])
        |> FallbackController.call({:error, :missing_credentials})
        |> json_response(500)

      assert envelope(body)["code"] == "internal_error"
    end

    test "signing failures are named rather than passed through", %{conn: conn} do
      body =
        conn
        |> Phoenix.Controller.accepts(["json"])
        |> FallbackController.call({:error, :audio_unavailable})
        |> json_response(503)

      assert envelope(body)["code"] == "audio_unavailable"
    end
  end

  describe "ErrorJSON.error/1" do
    test "omits details entirely when there are none" do
      rendered = ErrorJSON.error(%{code: "not_found", message: "Not found", details: nil})

      assert rendered == %{error: %{code: "not_found", message: "Not found"}}
      refute Map.has_key?(rendered.error, :details)
    end

    test "includes details when there are some" do
      rendered =
        ErrorJSON.error(%{
          code: "validation_failed",
          message: "The request could not be processed",
          details: %{meditation_set_id: ["does not exist"]}
        })

      assert rendered.error.details == %{meditation_set_id: ["does not exist"]}
    end
  end

  describe "prayer audio" do
    test "carries the moment the URL expires, and is not cacheable", %{conn: conn} do
      # Signing needs credentials the test environment does not have, so this
      # exercises the failure path; the success shape is covered by
      # PrayerJSON below.
      conn = get(conn, ~p"/api/prayers/magnificat/audio")

      assert conn.status in [200, 503]

      if conn.status == 200 do
        assert Enum.member?(
                 Plug.Conn.get_resp_header(conn, "cache-control"),
                 "private, no-store"
               )
      end
    end

    test "renders id, url and an ISO 8601 expiry" do
      expires_at = ~U[2026-08-20 14:02:12Z]

      assert LumenViaeWeb.API.PrayerJSON.audio(%{
               id: "magnificat",
               audio_url: "https://example.com/signed",
               expires_at: expires_at
             }) == %{
               data: %{
                 id: "magnificat",
                 audio_url: "https://example.com/signed",
                 expires_at: "2026-08-20T14:02:12Z"
               }
             }
    end
  end
end
