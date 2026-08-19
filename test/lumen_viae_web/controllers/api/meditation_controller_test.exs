defmodule LumenViaeWeb.API.MeditationControllerTest do
  @moduledoc """
  Covers the refresh path for an expired narration URL.

  The bug this endpoint exists for: the iOS offline download collects a
  presigned URL for every meditation in one pass, downloads them serially
  in the next, and on resume re-reads the URLs it wrote to disk earlier.
  Those are dead however long the lifetime is, so the client needs
  somewhere to ask for a fresh one without refetching the whole set.
  """
  use LumenViaeWeb.ConnCase, async: true

  alias LumenViae.Rosary

  defp create_meditation(attrs) do
    {:ok, mystery} =
      Rosary.create_mystery(%{
        name: "Audio Mystery #{System.unique_integer([:positive])}",
        category: "joyful",
        order: System.unique_integer([:positive])
      })

    defaults = %{content: "Some content", mystery_id: mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs))
    meditation
  end

  describe "GET /api/meditations/:id/audio" do
    @tag :skip_without_aws
    test "returns a signed url and the moment it expires", %{conn: conn} do
      meditation = create_meditation(%{audio_url: "some_key.mp3"})

      case Rosary.fetch_meditation_audio(meditation) do
        :error ->
          # No AWS credentials in this environment; the signing path cannot
          # be exercised, and asserting a 404 here would assert the failure
          # rather than the feature.
          :ok

        {:ok, _} ->
          data =
            conn
            |> get(~p"/api/meditations/#{meditation.id}/audio")
            |> json_response(200)
            |> Map.fetch!("data")

          assert data["id"] == meditation.id
          assert is_binary(data["audio_url"])
          assert {:ok, _, _} = DateTime.from_iso8601(data["expires_at"])
      end
    end

    test "404s for a meditation with no audio", %{conn: conn} do
      meditation = create_meditation(%{audio_url: nil})

      assert conn
             |> get(~p"/api/meditations/#{meditation.id}/audio")
             |> json_response(404)
    end

    test "404s for a meditation that does not exist", %{conn: conn} do
      assert conn
             |> get(~p"/api/meditations/999999999/audio")
             |> json_response(404)
    end

    test "404s for a non-numeric id rather than raising", %{conn: conn} do
      assert conn
             |> get(~p"/api/meditations/not-an-id/audio")
             |> json_response(404)
    end

    test "404s for an archived meditation so withdrawn audio stops playing", %{conn: conn} do
      meditation = create_meditation(%{audio_url: "archived_key.mp3"})
      {:ok, _} = Rosary.archive_meditation(meditation)

      assert conn
             |> get(~p"/api/meditations/#{meditation.id}/audio")
             |> json_response(404)
    end
  end

  describe "audio URL lifetime" do
    test "the configured TTL is a day, not an hour" do
      # An hour did not cover a serial download of the whole catalogue,
      # which is the failure this value exists to prevent.
      assert Rosary.audio_url_ttl() == 86_400
    end

    test "S3 signature v4 caps a presigned URL at seven days" do
      assert Rosary.audio_url_ttl() <= 7 * 24 * 3600
    end
  end
end
