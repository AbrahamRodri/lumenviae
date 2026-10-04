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
      Rosary.create_mystery(
        %{
          name: "Refresh Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    meditation = fn content ->
      {:ok, m} =
        Rosary.create_meditation(%{content: content, mystery_id: mystery.id}, actor: admin())

      # In a set, as every meditation the public can reach is.
      LumenViae.Test.Sets.put_in_a_set(m)
    end

    both = meditation.("Both")
    {:ok, _} = Rosary.record_narration(both, "male", "voices/male/both.mp3", actor: admin())
    {:ok, _} = Rosary.record_narration(both, "female", "voices/female/both.mp3", actor: admin())

    male_only = meditation.("Male")
    {:ok, _} = Rosary.record_narration(male_only, "male", "voices/male/male.mp3", actor: admin())

    silent = meditation.("Silent")

    archived = meditation.("Archived")

    {:ok, _} =
      Rosary.record_narration(archived, "female", "voices/female/archived.mp3", actor: admin())

    {:ok, _} = Rosary.archive_meditation(archived, actor: admin())

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

  test "a voice is a preference: each answer names the voice it is in", %{
    conn: conn,
    both: both,
    male_only: male_only
  } do
    %{"data" => %{"meditationAudio" => answers}} =
      refresh(conn, [both.id, male_only.id], "male")

    # Where REST is exact (a 404 for a voice not recorded), GraphQL falls
    # back to the default and says which voice it served.
    assert [
             %{"meditationId" => both_id, "voice" => "male"},
             %{"meditationId" => male_id, "voice" => "male"}
           ] = answers

    assert both_id == to_string(both.id)
    assert male_id == to_string(male_only.id)

    %{"data" => %{"meditationAudio" => [fallback]}} = refresh(conn, [male_only.id], "female")
    assert fallback["voice"] == "male"
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

  test "a recording that cannot be signed fails the field, not the document", %{
    conn: conn,
    both: both
  } do
    put_env([{:ex_aws, :access_key_id, nil}, {:ex_aws, :secret_access_key, nil}])

    body =
      graphql(
        conn,
        """
        query Refresh($ids: [ID!]!) {
          meditationAudio(meditationIds: $ids) { meditationId }
          voices { slug }
        }
        """,
        %{ids: [to_string(both.id)]}
      )

    # Not [], which would read as "withdrawn" and make a player skip it.
    assert body["data"]["meditationAudio"] == nil
    assert [%{"code" => "audio_unavailable", "path" => ["meditationAudio"]}] = body["errors"]
    assert [_ | _] = body["data"]["voices"]
  end

  test "every id answered is digits", %{conn: conn, both: both, male_only: male_only} do
    %{"data" => %{"meditationAudio" => answers}} = refresh(conn, [both.id, male_only.id])

    assert Enum.all?(answers, &(&1["meditationId"] =~ ~r/^\d+$/))
  end

  test "an unknown voice is no preference", %{conn: conn, both: both} do
    body = refresh(conn, [both.id], "nobody")

    refute Map.has_key?(body, "errors")
    assert [%{"voice" => voice}] = body["data"]["meditationAudio"]
    assert voice == LumenViae.Rosary.Voices.default().slug
  end
end
