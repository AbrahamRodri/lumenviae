defmodule LumenViae.Curation.AudioRegenerationTest do
  use LumenViae.DataCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Curation.AudioRegeneration
  alias LumenViae.Rosary

  @content "First paragraph.\n\nSecond paragraph."
  @annotations [%{"offset" => 16, "seconds" => 2.5}]

  setup do
    {:ok, mystery} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1})

    {:ok, set} = Rosary.create_meditation_set(%{"name" => "Regen Set", "category" => "joyful"})

    {:ok, with_audio} =
      Rosary.create_meditation(%{
        "content" => @content,
        "mystery_id" => mystery.id,
        "title" => "Fiat",
        "audio_url" => "regen_clip.mp3",
        "tts_annotations" => @annotations
      })

    {:ok, without_audio} =
      Rosary.create_meditation(%{"content" => @content, "mystery_id" => mystery.id})

    {:ok, _} = Rosary.add_meditation_to_set(set.id, with_audio.id, 1)
    {:ok, _} = Rosary.add_meditation_to_set(set.id, without_audio.id, 2)

    %{set: set, with_audio: with_audio, without_audio: without_audio, mystery: mystery}
  end

  defp stub_apis do
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
      send(test_pid, {:tts_text, conn.request_path, Jason.decode!(body)["text"]})

      conn
      |> Plug.Conn.put_resp_content_type("audio/mpeg")
      |> Plug.Conn.send_resp(200, "regenerated-audio-bytes")
    end)

    test_pid
  end

  defp key_of(url), do: URI.parse(url).path

  test "dry run lists the pause plan per voice without calling ElevenLabs or S3", %{set: set} do
    stub_apis()

    results = AudioRegeneration.run({:set, set.name}, dry_run: true)

    assert [{:ok, female}, {:ok, male}, {:warning, skipped}] = results
    assert female =~ "Would regenerate voices/female/regen_clip.mp3"
    assert female =~ "Fiat"
    assert female =~ "female voice"
    # The custom pause sits at the only paragraph break and replaces it.
    assert female =~ "1 pause(s), 1 custom"
    assert male =~ "Would regenerate voices/male/regen_clip.mp3"
    assert skipped =~ "no audio file"

    refute_received {:tts_text, _, _}
    refute_received {:aws_request, _, _, _}
  end

  test "regenerates every voice under its prefix and records the narrations", %{
    set: set,
    with_audio: with_audio
  } do
    stub_apis()
    meditations_before = Rosary.count_meditations()

    results = AudioRegeneration.run({:set, set.name})

    assert [{:ok, female}, {:ok, male}, {:warning, _skipped}] = results
    assert female =~ "Regenerated voices/female/regen_clip.mp3"
    assert male =~ "Regenerated voices/male/regen_clip.mp3"

    expected_text = "First paragraph. [long pause] Second paragraph."
    assert_received {:tts_text, "/v1/text-to-speech/Z3R5wn05IrDiVCyEkUrK", ^expected_text}
    assert_received {:tts_text, "/v1/text-to-speech/RTFg9niKcgGLDwa3RFlz", ^expected_text}

    assert_received {:aws_request, :put, female_url, "regenerated-audio-bytes"}
    assert_received {:aws_request, :put, male_url, "regenerated-audio-bytes"}

    assert Enum.sort(Enum.map([female_url, male_url], &key_of/1)) ==
             [
               "/lumenviae-audio/voices/female/regen_clip.mp3",
               "/lumenviae-audio/voices/male/regen_clip.mp3"
             ]

    assert Rosary.count_meditations() == meditations_before
    reloaded = Rosary.get_meditation!(with_audio.id)
    assert reloaded.content == @content
    assert reloaded.audio_url == "regen_clip.mp3"
    assert reloaded.tts_annotations == @annotations

    assert Enum.map(Rosary.meditation_narrations(reloaded), &{&1.voice.slug, &1.s3_key}) ==
             [{"female", "voices/female/regen_clip.mp3"}, {"male", "voices/male/regen_clip.mp3"}]
  end

  test "limits itself to the voices asked for", %{with_audio: with_audio} do
    stub_apis()

    assert [{:ok, message}] =
             AudioRegeneration.run({:meditation, with_audio.id}, voices: ["female"])

    assert message =~ "Regenerated voices/female/regen_clip.mp3"
    assert_received {:tts_text, "/v1/text-to-speech/Z3R5wn05IrDiVCyEkUrK", _}
    refute_received {:tts_text, _, _}

    assert [%{voice: %{slug: "female"}}] =
             Rosary.meditation_narrations(Rosary.get_meditation!(with_audio.id))
  end

  test "rejects an unknown voice before spending anything", %{with_audio: with_audio} do
    stub_apis()

    assert [{:error, message}] =
             AudioRegeneration.run({:meditation, with_audio.id}, voices: ["female", "tenor"])

    assert message =~ "Unknown voice(s): tenor"
    refute_received {:tts_text, _, _}
  end

  test "only_missing keeps recordings already on record", %{with_audio: with_audio} do
    stub_apis()
    {:ok, _} = Rosary.record_narration(with_audio, "male", "voices/male/regen_clip.mp3")

    results = AudioRegeneration.run({:meditation, with_audio.id}, only_missing: true)

    assert [{:ok, female}, {:ok, male}] = results
    assert female =~ "Regenerated voices/female/regen_clip.mp3"
    assert male =~ "Kept voices/male/regen_clip.mp3"

    assert_received {:tts_text, "/v1/text-to-speech/Z3R5wn05IrDiVCyEkUrK", _}
    refute_received {:tts_text, _, _}
  end

  test ":all covers every active meditation with a filename, in id order", %{
    with_audio: with_audio,
    mystery: mystery
  } do
    stub_apis()

    {:ok, later} =
      Rosary.create_meditation(%{
        "content" => @content,
        "mystery_id" => mystery.id,
        "audio_url" => "later_clip.mp3"
      })

    {:ok, archived} =
      Rosary.create_meditation(%{
        "content" => @content,
        "mystery_id" => mystery.id,
        "audio_url" => "archived_clip.mp3"
      })

    {:ok, _} = Rosary.archive_meditation(archived)

    results = AudioRegeneration.run(:all, voices: ["female"], dry_run: true)

    assert [{:ok, first}, {:warning, _no_file}, {:ok, second}] = results
    assert first =~ "meditation #{with_audio.id}"
    assert second =~ "meditation #{later.id}"
    refute Enum.any?(results, fn {_, message} -> message =~ "archived_clip" end)
  end

  test "reports unknown targets as errors through the progress fun" do
    test_pid = self()

    results =
      AudioRegeneration.run({:set, "No Such Set"},
        progress: fn event -> send(test_pid, {:progress, event}) end
      )

    assert [{:error, message}] = results
    assert message =~ "Meditation set not found: No Such Set"
    assert_received {:progress, {:item_finished, 1, 1, {:error, _}}}

    assert [{:error, not_found}] = AudioRegeneration.run({:meditation, 999_999})
    assert not_found =~ "Meditation not found"
  end
end
