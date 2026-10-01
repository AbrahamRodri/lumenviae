defmodule LumenViaeWeb.Graphql.RecordingsTest do
  @moduledoc """
  The narration voices and the spoken Rosary over GraphQL, held to the
  same recordings, keys and files as `GET /api/voices` and
  `GET /api/rosary/audio`, and to the shapes the iOS app would decode
  (docs/IOS_API_CONTRACT.md).

  Not async: the retired-voice tests put a production-like voice line-up
  into application config for their duration.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1, put_env: 3]
  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.{PrayerAudio, Voices}

  # The strict form the app's ISO8601DateFormatter accepts: whole seconds, Z.
  @expiry ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

  # Presigning is local arithmetic over the credentials, so stub ones are
  # enough to exercise the whole signing path without reaching AWS.
  setup do
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")
    :ok
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

  describe "voices" do
    @voices_query "{ voices { slug name description default retired replacedBy } }"

    test "lists the same voices as GET /api/voices, in the same order", %{conn: conn} do
      %{"data" => %{"voices" => voices}} = graphql(conn, @voices_query)
      rest = conn |> get("/api/voices") |> json_response(200) |> Map.fetch!("data")

      assert Enum.map(voices, & &1["slug"]) == Enum.map(rest, & &1["slug"])
      assert Enum.map(voices, & &1["default"]) == Enum.map(rest, & &1["default"])
    end

    test "has exactly one default, and it comes first", %{conn: conn} do
      %{"data" => %{"voices" => [first | rest] = voices}} = graphql(conn, @voices_query)

      assert first["default"] == true
      assert first["slug"] == Voices.default().slug
      assert Enum.all?(rest, &(&1["default"] == false))

      for voice <- voices do
        assert is_binary(voice["slug"])
        assert is_binary(voice["name"])
        assert is_boolean(voice["default"])
        assert voice["retired"] == false
        assert voice["replacedBy"] == nil
      end
    end

    test "leaves out a retired voice, and lists it with its successor under retiredVoices",
         %{conn: conn} do
      production_line_up()

      %{"data" => %{"voices" => voices}} = graphql(conn, @voices_query)
      assert Enum.map(voices, & &1["slug"]) == ["frederick", "female"]

      %{"data" => %{"retiredVoices" => retired}} =
        graphql(conn, "{ retiredVoices { slug retired replacedBy } }")

      assert retired == [%{"slug" => "male", "retired" => true, "replacedBy" => "frederick"}]
    end
  end

  describe "rosaryAudio" do
    @everything """
    query Pack($voice: String) {
      rosaryAudio(voice: $voice) {
        voice version expiresAt
        prayers { id title file audio { url expiresAt } }
        announcements { key text file audio { url expiresAt } }
        verses { key clips { bead reference file audio { url expiresAt } } }
        book { id title file audio { url expiresAt } }
      }
    }
    """

    test "serves the default voice's whole catalogue", %{conn: conn} do
      %{"data" => %{"rosaryAudio" => pack}} = graphql(conn, @everything)
      voice = Voices.default()

      assert pack["voice"] == voice.slug
      assert pack["version"] == PrayerAudio.version(voice, PrayerAudio.clips())
      assert pack["expiresAt"] =~ @expiry

      assert Enum.map(pack["prayers"], & &1["id"]) == PrayerAudio.prayer_ids()
      assert length(pack["announcements"]) == length(PrayerAudio.announcements())
      assert length(pack["book"]) == length(PrayerAudio.book())
    end

    test "hands out the same files and keys as GET /api/rosary/audio", %{conn: conn} do
      %{"data" => %{"rosaryAudio" => pack}} = graphql(conn, @everything)

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
    end

    test "every clip carries a signed URL and an expiry in the strict form", %{conn: conn} do
      %{"data" => %{"rosaryAudio" => pack}} = graphql(conn, @everything)

      clips =
        pack["prayers"] ++
          pack["announcements"] ++
          pack["book"] ++ Enum.flat_map(pack["verses"], & &1["clips"])

      for clip <- clips do
        assert is_binary(clip["file"])
        assert clip["audio"]["url"] =~ "X-Amz-Signature="
        assert clip["audio"]["expiresAt"] =~ @expiry
        assert clip["audio"]["expiresAt"] >= pack["expiresAt"]
      end
    end

    test "keys every mystery and keeps each mystery's verses in bead order", %{conn: conn} do
      %{"data" => %{"rosaryAudio" => pack}} = graphql(conn, @everything)

      expected_keys =
        for {category, count} <- [
              joyful: 5,
              sorrowful: 5,
              glorious: 5,
              luminous: 5,
              seven_sorrows: 7
            ],
            n <- 1..count,
            do: "#{category}_#{n}"

      assert Enum.sort(Enum.map(pack["announcements"], & &1["key"])) == Enum.sort(expected_keys)
      assert Enum.sort(Enum.map(pack["verses"], & &1["key"])) == Enum.sort(expected_keys)

      catalogue = Enum.group_by(PrayerAudio.verses(), & &1.mystery)

      for group <- pack["verses"] do
        beads = Enum.map(group["clips"], & &1["bead"])
        assert beads == Enum.to_list(1..length(beads))

        assert Enum.map(group["clips"], & &1["reference"]) ==
                 catalogue |> Map.fetch!(group["key"]) |> Enum.map(& &1.reference)
      end
    end

    test "a retired voice is answered by its successor", %{conn: conn} do
      production_line_up()

      %{"data" => %{"rosaryAudio" => pack}} =
        graphql(conn, "query { rosaryAudio(voice: \"male\") { voice } }")

      assert pack["voice"] == "frederick"
    end

    test "an unknown voice is an invalid_argument error on voice", %{conn: conn} do
      body = graphql(conn, "query { rosaryAudio(voice: \"nobody\") { voice } }")

      assert body["data"] == nil
      assert [%{"code" => "invalid_argument", "fields" => ["voice"]}] = body["errors"]
    end

    test "signs only the kinds a query selects", %{conn: conn} do
      # With no credentials nothing can be signed. A query that selects no
      # clips must still succeed, which it can only do if it signed nothing.
      put_env([{:ex_aws, :access_key_id, nil}, {:ex_aws, :secret_access_key, nil}])

      assert %{"data" => %{"rosaryAudio" => %{"voice" => _, "version" => _}}} =
               graphql(conn, "{ rosaryAudio { voice version } }")
    end

    test "a recording that cannot be signed is an audio_unavailable error", %{conn: conn} do
      put_env([{:ex_aws, :access_key_id, nil}, {:ex_aws, :secret_access_key, nil}])

      body = graphql(conn, "{ rosaryAudio { prayers { id } } }")

      assert [%{"code" => "audio_unavailable"}] = body["errors"]
    end
  end
end
