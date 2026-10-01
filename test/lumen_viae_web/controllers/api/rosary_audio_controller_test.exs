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

  # R1, R2
  test "voice, version and expiry are typed the way the app parses them", %{conn: conn} do
    data = manifest(conn)

    assert is_binary(data["voice"])
    assert is_binary(data["version"])
    # ISO8601DateFormatter() defaults reject fractional seconds, and a failed
    # parse marks the manifest stale on every launch. DateTime.from_iso8601
    # accepts things the app rejects, so the shape is matched instead.
    assert_utc_second(data["expires_at"], "expires_at")
  end

  # R3: literal, because PrayerAudio.prayer_ids() would only compare the
  # server with itself.
  test "every prayer the app looks up by id is served, with a file and a url", %{conn: conn} do
    data = manifest(conn)

    for id <-
          ~w(sign_of_cross apostles_creed our_father hail_mary glory_be fatima_prayer
             hail_holy_queen rosary_closing_prayer act_of_contrition sorrows_closing_prayer
             memorare st_michael_prayer) do
      assert %{"file" => file, "audio_url" => url} = data["prayers"][id], "missing prayer #{id}"
      assert is_binary(file)
      assert is_binary(url)
    end
  end

  # R4: literal keys again.
  test "an announcement and a verse list exist for every mystery the app prays", %{conn: conn} do
    data = manifest(conn)

    keys =
      for {category, count} <-
            [joyful: 5, sorrowful: 5, glorious: 5, luminous: 5, seven_sorrows: 7],
          n <- 1..count,
          do: "#{category}_#{n}"

    assert length(keys) == 27

    for key <- keys do
      announcement = data["announcements"][key]
      assert is_map(announcement), "no announcement for #{key}"
      assert is_binary(announcement["file"])
      assert is_binary(announcement["audio_url"])
      assert_string_or_nil(announcement["text"], "#{key} text")

      verses = data["verses"][key]
      assert is_list(verses) and verses != [], "no verses for #{key}"

      for verse <- verses do
        assert is_binary(verse["file"])
        assert is_binary(verse["audio_url"])
        assert_string_or_nil(verse["reference"], "#{key} reference")
      end
    end
  end

  # R5: the app reads verses[key][n - 1] as Hail Mary n, so the list order
  # is the bead order of the app's own export, for every mystery.
  test "each mystery's verses come in the export's bead order", %{conn: conn} do
    export =
      :lumen_viae
      |> Application.app_dir("priv/rosary_audio/scriptural_rosary.json")
      |> File.read!()
      |> Jason.decode!()

    verses = manifest(conn)["verses"]

    for {key, beads} <- export do
      assert Enum.map(verses[key], & &1["reference"]) == Enum.map(beads, & &1["reference"]),
             "#{key} is out of bead order"
    end
  end

  # R6: the app sorts and comma-joins its kinds. A kind it did not ask for
  # must be absent, because it treats any non-nil map as "this kind is held".
  describe "the include strings the app sends" do
    test "announcements,prayers,verses leaves the book absent", %{conn: conn} do
      data = manifest(conn, "?include=announcements,prayers,verses")

      for kind <- ~w(announcements prayers verses), do: assert(is_map(data[kind]))
      refute Map.has_key?(data, "book")
    end

    test "book alone serves only the book", %{conn: conn} do
      data = manifest(conn, "?include=book")

      assert is_map(data["book"]) and data["book"] != %{}
      for kind <- ~w(announcements prayers verses), do: refute(Map.has_key?(data, kind))
    end

    test "all four kinds serve all four", %{conn: conn} do
      data = manifest(conn, "?include=announcements,book,prayers,verses")

      for kind <- ~w(announcements book prayers verses), do: assert(is_map(data[kind]))
    end
  end

  # G2: URLSession's default Accept.
  test "answers */* with 200 JSON", %{conn: conn} do
    assert conn
           |> Plug.Conn.put_req_header("accept", "*/*")
           |> get("/api/rosary/audio")
           |> json_response(200)
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

  test "?include=book serves the Prayer Book's prayers, by the book's ids", %{conn: conn} do
    full = manifest(conn)
    data = manifest(conn, "?include=prayers,book&voice=male")

    assert map_size(data["book"]) == length(PrayerAudio.book())
    assert data["book"]["angelus"]["file"] =~ ~r/^angelus-[0-9a-f]{10}\.mp3$/
    assert data["book"]["angelus"]["audio_url"] =~ "voices/male/rosary/books/"
    assert Map.has_key?(data, "prayers")
    refute Map.has_key?(data, "verses")
    refute Map.has_key?(full, "book")
  end

  # R7: the app retries with the default voice on 400 and only on 400.
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
