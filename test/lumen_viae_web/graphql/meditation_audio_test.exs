defmodule LumenViaeWeb.Graphql.MeditationAudioTest do
  @moduledoc """
  `meditationAudio`, the plural of `GET /api/meditations/:id/audio`: fresh
  narration URLs for a stored set's meditations, under the same rules as
  the REST endpoint, with nothing-to-play left out instead of failing the
  batch.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]
  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary

  @expiry ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

  @query """
  query Refresh($ids: [ID!]!, $voice: String) {
    meditationAudio(meditationIds: $ids, voice: $voice) {
      meditationId voice audio { url expiresAt }
    }
  }
  """

  setup do
    put_env([
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    {:ok, mystery} =
      Rosary.create_mystery(%{
        name: "Refresh Mystery #{System.unique_integer([:positive])}",
        category: "joyful",
        order: System.unique_integer([:positive])
      })

    meditation = fn content ->
      {:ok, m} = Rosary.create_meditation(%{content: content, mystery_id: mystery.id})
      m
    end

    both = meditation.("Both")
    {:ok, _} = Rosary.record_narration(both, "male", "voices/male/both.mp3")
    {:ok, _} = Rosary.record_narration(both, "female", "voices/female/both.mp3")

    male_only = meditation.("Male")
    {:ok, _} = Rosary.record_narration(male_only, "male", "voices/male/male.mp3")

    silent = meditation.("Silent")

    archived = meditation.("Archived")
    {:ok, _} = Rosary.record_narration(archived, "female", "voices/female/archived.mp3")
    {:ok, _} = Rosary.archive_meditation(archived)

    %{both: both, male_only: male_only, silent: silent, archived: archived}
  end

  defp key_of(url), do: URI.parse(url).path

  defp refresh(conn, ids, voice \\ nil) do
    variables = %{ids: Enum.map(ids, &to_string/1), voice: voice}
    graphql(conn, @query, variables)
  end

  test "signs the default voice for each meditation, in the order asked", %{
    conn: conn,
    both: both,
    male_only: male_only
  } do
    %{"data" => %{"meditationAudio" => answers}} = refresh(conn, [male_only.id, both.id])

    assert [
             %{"meditationId" => male_id, "voice" => "male", "audio" => male_audio},
             %{"meditationId" => both_id, "voice" => "female", "audio" => both_audio}
           ] = answers

    # GraphQL IDs travel as strings and name the same integer ids.
    assert male_id == to_string(male_only.id)
    assert both_id == to_string(both.id)

    assert key_of(male_audio["url"]) == "/lumenviae-audio/voices/male/male.mp3"
    assert key_of(both_audio["url"]) == "/lumenviae-audio/voices/female/both.mp3"
    assert male_audio["expiresAt"] =~ @expiry
  end

  test "a named voice is exact, as on the REST endpoint", %{
    conn: conn,
    both: both,
    male_only: male_only
  } do
    %{"data" => %{"meditationAudio" => answers}} =
      refresh(conn, [both.id, male_only.id], "female")

    # male_only has no female recording, so it is left out rather than
    # answered in another voice.
    assert [%{"meditationId" => id, "voice" => "female"}] = answers
    assert id == to_string(both.id)
  end

  test "leaves out what cannot be played instead of failing the batch", %{
    conn: conn,
    both: both,
    silent: silent,
    archived: archived
  } do
    %{"data" => %{"meditationAudio" => answers}} =
      refresh(conn, [silent.id, archived.id, 999_999_999, both.id])

    assert Enum.map(answers, & &1["meditationId"]) == [to_string(both.id)]
  end

  test "agrees with GET /api/meditations/:id/audio on the recording", %{
    conn: conn,
    both: both
  } do
    rest = conn |> get("/api/meditations/#{both.id}/audio?voice=male") |> json_response(200)

    %{"data" => %{"meditationAudio" => [answer]}} = refresh(conn, [both.id], "male")

    assert answer["voice"] == rest["data"]["voice"]
    assert key_of(answer["audio"]["url"]) == key_of(rest["data"]["audio_url"])
  end

  test "an unknown voice is an invalid_argument error on voice", %{conn: conn, both: both} do
    body = refresh(conn, [both.id], "nobody")

    assert body["data"] == nil
    assert [%{"code" => "invalid_argument", "fields" => ["voice"]}] = body["errors"]
  end
end
