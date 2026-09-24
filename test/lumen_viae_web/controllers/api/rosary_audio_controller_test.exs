defmodule LumenViaeWeb.API.RosaryAudioControllerTest do
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Rosary.{PrayerAudio, Voices}

  # Presigning is local arithmetic over the credentials, so stub ones are
  # enough to exercise the whole signing path without reaching AWS.
  setup do
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")
    :ok
  end

  defp manifest(conn, query \\ "") do
    conn |> get("/api/rosary/audio#{query}") |> json_response(200) |> Map.fetch!("data")
  end

  test "serves every clip in the default voice, grouped as the app looks them up", %{conn: conn} do
    response = get(conn, "/api/rosary/audio")
    assert get_resp_header(response, "cache-control") == ["private, no-store"]

    data = json_response(response, 200)["data"]
    voice = Voices.default()

    assert data["voice"] == voice.slug
    assert data["version"] == PrayerAudio.version(voice, PrayerAudio.clips())
    assert {:ok, _, _} = DateTime.from_iso8601(data["expires_at"])

    assert Map.keys(data["prayers"]) |> Enum.sort() == Enum.sort(PrayerAudio.prayer_ids())
    hail_mary = data["prayers"]["hail_mary"]
    assert hail_mary["file"] =~ ~r/^hail_mary-[0-9a-f]{10}\.mp3$/
    assert hail_mary["audio_url"] =~ "voices/#{voice.slug}/rosary/prayers/#{hail_mary["file"]}"

    assert map_size(data["announcements"]) == 27

    assert data["announcements"]["joyful_1"]["text"] ==
             "The First Joyful Mystery: The Annunciation"

    assert map_size(data["verses"]) == 27
    assert length(data["verses"]["joyful_1"]) == 10
    assert length(data["verses"]["seven_sorrows_1"]) == 7
    assert hd(data["verses"]["joyful_1"])["reference"] == "Luke 1:26"
  end

  test "?voice picks the voice and keys its files under that voice", %{conn: conn} do
    data = manifest(conn, "?voice=male")

    assert data["voice"] == "male"
    assert data["prayers"]["our_father"]["audio_url"] =~ "voices/male/rosary/prayers/"
  end

  test "?include narrows the kinds served but not the version", %{conn: conn} do
    full = manifest(conn)
    data = manifest(conn, "?include=prayers,announcements")

    assert Map.has_key?(data, "prayers")
    assert Map.has_key?(data, "announcements")
    refute Map.has_key?(data, "verses")
    assert data["version"] == full["version"]
  end

  test "an unknown voice is a 400 naming it", %{conn: conn} do
    body = conn |> get("/api/rosary/audio?voice=tenor") |> json_response(400)
    assert body["error"]["message"] =~ "tenor"
  end

  test "an unknown include is a 400 naming the kinds allowed", %{conn: conn} do
    body = conn |> get("/api/rosary/audio?include=chants") |> json_response(400)
    assert body["error"]["message"] =~ "chants"
    assert body["error"]["message"] =~ "verses"
  end

  test "without credentials the manifest is a 503, not a crash", %{conn: conn} do
    put_env(:ex_aws, :access_key_id, nil)

    body = conn |> get("/api/rosary/audio") |> json_response(503)
    assert body["error"]["code"] == "audio_unavailable"
  end
end
