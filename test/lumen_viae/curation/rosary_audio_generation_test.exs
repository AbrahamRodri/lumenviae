defmodule LumenViae.Curation.RosaryAudioGenerationTest do
  use ExUnit.Case, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Curation.RosaryAudioGeneration
  alias LumenViae.Rosary.{PrayerAudio, Voices}

  # The fake S3 client answers every request 200, so every HEAD says the
  # clip exists.
  setup do
    test_pid = self()

    put_env(:lumen_viae, :eleven_labs_api_key, "test-api-key")
    put_env(:lumen_viae, :audio_retry_base_delay_ms, 1)
    put_env(:lumen_viae, :eleven_labs_req_options, plug: {Req.Test, LumenViae.Audio.ElevenLabs})
    put_env(:ex_aws, :http_client, LumenViae.Test.FakeAwsHttpClient)
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")
    put_env(:lumen_viae, :fake_aws_test_pid, test_pid)

    Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:tts_text, Jason.decode!(body)["text"]})

      conn
      |> Plug.Conn.put_resp_content_type("audio/mpeg")
      |> Plug.Conn.send_resp(200, "audio-bytes")
    end)

    :ok
  end

  test "a clip already at its key is skipped without calling ElevenLabs" do
    results = RosaryAudioGeneration.run(voices: ["female"], kinds: [:prayer])

    assert length(results) == length(PrayerAudio.prayers())
    assert Enum.all?(results, &match?({:warning, _}, &1))
    refute_received {:tts_text, _}
    refute_received {:aws_request, :put, _, _}
  end

  test "a dry run with --force lists every clip and spends nothing" do
    results =
      RosaryAudioGeneration.run(
        voices: ["female", "male"],
        kinds: [:prayer],
        dry_run: true,
        force: true
      )

    assert length(results) == 2 * length(PrayerAudio.prayers())
    assert {:ok, message} = hd(results)
    assert message =~ "female prayer sign_of_cross: would record"
    assert message =~ "voices/female/rosary/prayers/sign_of_cross-"
    refute_received {:tts_text, _}
    refute_received {:aws_request, _, _, _}
  end

  test "--force records the speech text and uploads it to the clip's key" do
    [result] =
      RosaryAudioGeneration.run(voices: ["female"], kinds: [:prayer], force: true)
      |> Enum.filter(fn {_, message} -> message =~ "rosary_closing_prayer" end)

    assert {:ok, _} = result

    closing = Enum.find(PrayerAudio.prayers(), &(&1.name == "rosary_closing_prayer"))
    key = PrayerAudio.s3_key(Voices.get("female"), closing)

    assert_received {:tts_text, "Let us pray. O God, whose only-begotten Son" <> _}
    assert key =~ "voices/female/rosary/prayers/rosary_closing_prayer-"
    assert Enum.any?(uploaded_paths(), &String.ends_with?(&1, "/" <> key))
  end

  # The URL path of every PUT the fake S3 client saw; the clips are
  # recorded concurrently, so they arrive in no particular order.
  defp uploaded_paths do
    receive do
      {:aws_request, :put, url, "audio-bytes"} -> [URI.parse(url).path | uploaded_paths()]
    after
      0 -> []
    end
  end

  test "an unknown voice fails before anything is spent" do
    assert [{:error, message}] = RosaryAudioGeneration.run(voices: ["tenor"])
    assert message =~ "tenor"
    refute_received {:tts_text, _}
  end
end
