defmodule LumenViaeWeb.JsonApi.RecordingsTest do
  @moduledoc """
  The mysteries, the narration voices, the spoken Rosary and fresh
  meditation audio over `/api/v2`, held to the same records, recordings,
  keys and files as the unversioned REST API and GraphQL.

  Not async: the retired-voice tests put a production-like voice line-up
  into application config for their duration.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]
  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary
  alias LumenViae.Rosary.{PrayerAudio, Voices}

  # The strict form the app's ISO8601DateFormatter accepts: whole seconds, Z.
  @expiry ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

  @every_kind "fields[spoken_rosary]=version,expires_at,prayers,announcements,verses,book"

  # Presigning is local arithmetic over the credentials, so stub ones are
  # enough to exercise the whole signing path without reaching AWS.
  setup do
    put_env([
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    :ok
  end

  defp without_credentials do
    put_env([{:ex_aws, :access_key_id, nil}, {:ex_aws, :secret_access_key, nil}])
  end

  defp production_line_up do
    put_env([
      {:lumen_viae, :narration_voices,
       [
         %{
           slug: "frederick",
           name: "Male",
           eleven_labs_voice_id: "fr",
           model_id: "eleven_v4",
           rosary_audio_from: %{book: "female"},
           default: true
         },
         %{slug: "female", name: "Female", description: "Gentle", eleven_labs_voice_id: "f"},
         %{
           slug: "male",
           name: "Male (original)",
           eleven_labs_voice_id: "m",
           hidden: true,
           replaced_by: "frederick"
         }
       ]}
    ])
  end

  defp data(conn, path), do: conn |> get_v2(path) |> v2_response(200) |> Map.fetch!("data")

  describe "mysteries" do
    test "lists the same mysteries as GET /api/mysteries, in the same order", %{conn: conn} do
      for {category, order} <- [{"sorrowful", 2}, {"joyful", 3}, {"sorrowful", 1}] do
        {:ok, _} =
          Rosary.create_mystery(
            %{name: "#{category} #{order}", category: category, order: order},
            actor: admin()
          )
      end

      mysteries = data(conn, "/mysteries")
      rest = conn |> get("/api/mysteries") |> json_response(200) |> Map.fetch!("data")

      assert Enum.map(mysteries, & &1["id"]) == Enum.map(rest, &to_string(&1["id"]))

      for mystery <- mysteries do
        assert mystery["type"] == "mystery"

        assert Map.keys(mystery["attributes"]) |> Enum.sort() ==
                 ~w(category description name order scripture_reference)
      end
    end
  end

  describe "voices" do
    test "lists the same voices as GET /api/voices, in the same order", %{conn: conn} do
      voices = data(conn, "/voices")
      rest = conn |> get("/api/voices") |> json_response(200) |> Map.fetch!("data")

      assert Enum.map(voices, & &1["id"]) == Enum.map(rest, & &1["slug"])
      assert Enum.map(voices, & &1["attributes"]["default"]) == Enum.map(rest, & &1["default"])
    end

    test "has exactly one default, and it comes first", %{conn: conn} do
      [first | rest] = data(conn, "/voices")

      assert first["attributes"]["default"] == true
      assert first["id"] == Voices.default().slug
      assert Enum.all?(rest, &(&1["attributes"]["default"] == false))
    end

    test "leaves out a retired voice, and lists it with its successor under /voices/retired",
         %{conn: conn} do
      production_line_up()

      assert conn |> data("/voices") |> Enum.map(& &1["id"]) == ["frederick", "female"]

      assert [
               %{
                 "id" => "male",
                 "attributes" => %{"retired" => true, "replaced_by" => "frederick"}
               }
             ] =
               data(conn, "/voices/retired")
    end
  end

  describe "the spoken Rosary" do
    test "serves the default voice's whole catalogue", %{conn: conn} do
      pack = data(conn, "/rosary-audio?" <> @every_kind)
      voice = Voices.default()

      assert pack["id"] == voice.slug
      assert pack["attributes"]["version"] == PrayerAudio.version(voice, PrayerAudio.clips())
      assert pack["attributes"]["expires_at"] =~ @expiry
      assert Enum.map(pack["attributes"]["prayers"], & &1["id"]) == PrayerAudio.prayer_ids()
    end

    test "hands out the same files and keys as GET /api/rosary/audio", %{conn: conn} do
      pack = data(conn, "/rosary-audio?" <> @every_kind)["attributes"]

      rest =
        conn
        |> get("/api/rosary/audio?include=prayers,announcements,verses,book")
        |> json_response(200)
        |> Map.fetch!("data")

      assert pack["version"] == rest["version"]

      assert Map.new(pack["prayers"], &{&1["id"], &1["file"]}) ==
               Map.new(rest["prayers"], fn {id, clip} -> {id, clip["file"]} end)

      assert Map.new(pack["announcements"], &{&1["key"], {&1["file"], &1["text"]}}) ==
               Map.new(rest["announcements"], fn {key, clip} ->
                 {key, {clip["file"], clip["text"]}}
               end)

      assert Map.new(pack["verses"], &{&1["key"], Enum.map(&1["clips"], fn c -> c["file"] end)}) ==
               Map.new(rest["verses"], fn {key, clips} -> {key, Enum.map(clips, & &1["file"])} end)

      assert Map.new(pack["book"], &{&1["id"], &1["file"]}) ==
               Map.new(rest["book"], fn {id, clip} -> {id, clip["file"]} end)

      for clip <- pack["prayers"] do
        assert clip["audio"]["url"] =~ "X-Amz-Signature="
        assert clip["audio"]["expires_at"] =~ @expiry
      end
    end

    test "a retired voice is answered by its successor, an unknown one by the default", %{
      conn: conn
    } do
      production_line_up()

      assert data(conn, "/rosary-audio?voice=male")["id"] == "frederick"
      assert data(conn, "/rosary-audio?voice=nobody")["id"] == Voices.default().slug
    end

    test "by default signs nothing: the version alone tells a device whether its pack is current",
         %{conn: conn} do
      without_credentials()

      pack = data(conn, "/rosary-audio")

      assert Map.keys(pack["attributes"]) |> Enum.sort() == ["expires_at", "version"]
    end

    test "a recording that cannot be signed is a 503 audio_unavailable", %{conn: conn} do
      without_credentials()

      body =
        conn
        |> get_v2("/rosary-audio?fields[spoken_rosary]=prayers")
        |> v2_response(503)

      assert [%{"code" => "audio_unavailable", "detail" => "Audio temporarily unavailable"}] =
               body["errors"]
    end
  end

  describe "meditation audio" do
    setup do
      {:ok, mystery} =
        Rosary.create_mystery(
          %{
            name: "V2 Refresh #{System.unique_integer([:positive])}",
            category: "joyful",
            order: System.unique_integer([:positive])
          },
          actor: admin()
        )

      meditation = fn content ->
        {:ok, m} =
          Rosary.create_meditation(%{content: content, mystery_id: mystery.id}, actor: admin())

        m
      end

      both = meditation.("Both")
      {:ok, _} = Rosary.record_narration(both, "male", "voices/male/both.mp3", actor: admin())
      {:ok, _} = Rosary.record_narration(both, "female", "voices/female/both.mp3", actor: admin())

      male_only = meditation.("Male")

      {:ok, _} =
        Rosary.record_narration(male_only, "male", "voices/male/male.mp3", actor: admin())

      silent = meditation.("Silent")
      archived = meditation.("Archived")

      {:ok, _} =
        Rosary.record_narration(archived, "female", "voices/female/archived.mp3", actor: admin())

      {:ok, _} = Rosary.archive_meditation(archived, actor: admin())

      %{both: both, male_only: male_only, silent: silent, archived: archived}
    end

    defp key_of(url), do: URI.parse(url).path

    defp refresh(conn, ids, voice \\ nil, status \\ 201) do
      conn
      |> post_v2("/meditations/audio", %{data: %{meditation_ids: ids, voice: voice}})
      |> v2_response(status)
    end

    test "signs each meditation in the preferred voice where it has one, in the order asked", %{
      conn: conn,
      both: both,
      male_only: male_only
    } do
      assert [
               %{"meditation_id" => male_id, "voice" => "male", "audio" => male_audio},
               %{"meditation_id" => both_id, "voice" => "female", "audio" => both_audio}
             ] = refresh(conn, [male_only.id, both.id], "female")

      assert male_id == male_only.id
      assert both_id == both.id
      assert key_of(male_audio["url"]) == "/lumenviae-audio/voices/male/male.mp3"
      assert key_of(both_audio["url"]) == "/lumenviae-audio/voices/female/both.mp3"
      assert male_audio["expires_at"] =~ @expiry
    end

    test "leaves out what cannot be played instead of failing the batch", %{
      conn: conn,
      both: both,
      silent: silent,
      archived: archived
    } do
      answers = refresh(conn, [silent.id, archived.id, 999_999_999, both.id])

      assert Enum.map(answers, & &1["meditation_id"]) == [both.id]
    end

    test "agrees with GET /api/meditations/:id/audio on the recording", %{conn: conn, both: both} do
      rest = conn |> get("/api/meditations/#{both.id}/audio?voice=male") |> json_response(200)

      [answer] = refresh(conn, [both.id], "male")

      assert answer["voice"] == rest["data"]["voice"]
      assert key_of(answer["audio"]["url"]) == key_of(rest["data"]["audio_url"])
    end

    test "a recording that cannot be signed is a 503 audio_unavailable, not an empty list", %{
      conn: conn,
      both: both
    } do
      without_credentials()

      body = refresh(conn, [both.id], nil, 503)

      assert [%{"code" => "audio_unavailable"}] = body["errors"]
    end

    test "takes at most 200 ids", %{conn: conn} do
      body = refresh(conn, Enum.to_list(1..201), nil, 400)

      assert [%{"code" => "invalid_argument"} | _] = body["errors"]
    end
  end
end
