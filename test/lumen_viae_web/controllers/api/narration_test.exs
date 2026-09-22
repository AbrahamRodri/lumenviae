defmodule LumenViaeWeb.API.NarrationTest do
  @moduledoc """
  Narrations as the app sees them: one URL per voice on every meditation of
  a set, the legacy `audio_url` still pointing at the default voice, and
  the per-meditation refresh endpoint taking a voice.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Rosary

  setup do
    put_env([
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    {:ok, mystery} =
      Rosary.create_mystery(%{
        name: "Narration Mystery #{System.unique_integer([:positive])}",
        category: "joyful",
        order: System.unique_integer([:positive])
      })

    {:ok, set} = Rosary.create_meditation_set(%{name: "Narrated Set", category: "joyful"})

    {:ok, both} =
      Rosary.create_meditation(%{content: "Both", mystery_id: mystery.id, audio_url: "both.mp3"})

    {:ok, _} = Rosary.record_narration(both, "male", "voices/male/both.mp3")
    {:ok, _} = Rosary.record_narration(both, "female", "voices/female/both.mp3")

    {:ok, male_only} =
      Rosary.create_meditation(%{content: "Male", mystery_id: mystery.id, audio_url: "male.mp3"})

    {:ok, _} = Rosary.record_narration(male_only, "male", "voices/male/male.mp3")

    {:ok, silent} = Rosary.create_meditation(%{content: "Silent", mystery_id: mystery.id})

    {:ok, _} = Rosary.add_meditation_to_set(set.id, both.id, 1)
    {:ok, _} = Rosary.add_meditation_to_set(set.id, male_only.id, 2)
    {:ok, _} = Rosary.add_meditation_to_set(set.id, silent.id, 3)

    %{set: set, both: both, male_only: male_only, silent: silent}
  end

  defp key_of(url), do: URI.parse(url).path

  test "the set detail carries every voice, and audio_url follows the default voice", %{
    conn: conn,
    set: set
  } do
    [both, male_only, silent] =
      conn
      |> get(~p"/api/meditation-sets/#{set.id}")
      |> json_response(200)
      |> get_in(["data", "meditations"])

    assert [
             %{"voice" => "female", "audio_url" => female},
             %{"voice" => "male", "audio_url" => male}
           ] =
             both["narrations"]

    assert key_of(female) == "/lumenviae-audio/voices/female/both.mp3"
    assert key_of(male) == "/lumenviae-audio/voices/male/both.mp3"
    assert both["audio_url"] == female

    # The default voice has not recorded this one, so the legacy field
    # falls back to the voice that has rather than going silent.
    assert [%{"voice" => "male", "audio_url" => male_url}] = male_only["narrations"]
    assert male_only["audio_url"] == male_url

    assert silent["narrations"] == []
    assert silent["audio_url"] == nil
  end

  describe "GET /api/meditations/:id/audio" do
    test "serves the default voice, naming it", %{conn: conn, both: both} do
      data =
        conn
        |> get(~p"/api/meditations/#{both.id}/audio")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["id"] == both.id
      assert data["voice"] == "female"
      assert key_of(data["audio_url"]) == "/lumenviae-audio/voices/female/both.mp3"
      assert {:ok, _, _} = DateTime.from_iso8601(data["expires_at"])
    end

    test "serves the voice asked for", %{conn: conn, both: both} do
      data =
        conn
        |> get(~p"/api/meditations/#{both.id}/audio?voice=male")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["voice"] == "male"
      assert key_of(data["audio_url"]) == "/lumenviae-audio/voices/male/both.mp3"
    end

    test "falls back to the voice that exists when the default has not recorded it", %{
      conn: conn,
      male_only: male_only
    } do
      data =
        conn
        |> get(~p"/api/meditations/#{male_only.id}/audio")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["voice"] == "male"
    end

    test "404s for a voice that has not recorded the meditation", %{
      conn: conn,
      male_only: male_only
    } do
      assert conn
             |> get(~p"/api/meditations/#{male_only.id}/audio?voice=female")
             |> json_response(404)
    end

    test "400s for a voice that does not exist", %{conn: conn, both: both} do
      body =
        conn
        |> get(~p"/api/meditations/#{both.id}/audio?voice=tenor")
        |> json_response(400)

      assert body["error"]["code"] == "bad_request"
      assert body["error"]["message"] =~ "tenor"
    end

    test "an empty voice parameter means the default", %{conn: conn, both: both} do
      data =
        conn
        |> get(~p"/api/meditations/#{both.id}/audio?voice=")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["voice"] == "female"
    end
  end
end
