defmodule LumenViae.Meditations.AudioRegenerationTest do
  use LumenViae.DataCase, async: false

  alias LumenViae.Meditations.AudioRegeneration
  alias LumenViae.Rosary
  alias LumenViae.Rosary.{Meditation, Mystery}

  @content "First paragraph.\n\nSecond paragraph."
  @annotations [%{"offset" => 16, "seconds" => 2.5}]

  setup do
    {:ok, mystery} =
      %Mystery{}
      |> Mystery.changeset(%{name: "The Annunciation", category: "joyful", order: 1})
      |> Repo.insert()

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

    %{set: set, with_audio: with_audio, without_audio: without_audio}
  end

  defp put_env(app, key, value) do
    original = Application.get_env(app, key)
    Application.put_env(app, key, value)

    on_exit(fn ->
      if original == nil,
        do: Application.delete_env(app, key),
        else: Application.put_env(app, key, original)
    end)
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
      send(test_pid, {:tts_text, Jason.decode!(body)["text"]})

      conn
      |> Plug.Conn.put_resp_content_type("audio/mpeg")
      |> Plug.Conn.send_resp(200, "regenerated-audio-bytes")
    end)

    test_pid
  end

  test "dry run lists the pause plan without calling ElevenLabs or S3", %{set: set} do
    stub_apis()

    results = AudioRegeneration.run({:set, set.name}, dry_run: true)

    assert [{:ok, would}, {:warning, skipped}] = results
    assert would =~ "Would regenerate regen_clip.mp3"
    assert would =~ "Fiat"
    # The custom pause sits at the only paragraph break and replaces it.
    assert would =~ "1 break tag(s), 1 custom pause(s)"
    assert skipped =~ "no audio file"

    refute_received {:tts_text, _}
    refute_received {:aws_request, _, _, _}
  end

  test "regenerates audio in place with pause tags, without touching meditations", %{
    set: set,
    with_audio: with_audio
  } do
    stub_apis()
    meditations_before = Repo.aggregate(Meditation, :count)

    results = AudioRegeneration.run({:set, set.name})

    assert [{:ok, regenerated}, {:warning, _skipped}] = results
    assert regenerated =~ "Regenerated regen_clip.mp3"

    assert_received {:tts_text, text}
    assert text == ~s(First paragraph. <break time="2.5s" /> Second paragraph.)

    assert_received {:aws_request, :put, url, "regenerated-audio-bytes"}
    assert url =~ "regen_clip.mp3"

    assert Repo.aggregate(Meditation, :count) == meditations_before
    reloaded = Repo.get!(Meditation, with_audio.id)
    assert reloaded.content == @content
    assert reloaded.audio_url == "regen_clip.mp3"
    assert reloaded.tts_annotations == @annotations
  end

  test "targets a single meditation by id", %{with_audio: with_audio} do
    stub_apis()

    assert [{:ok, message}] = AudioRegeneration.run({:meditation, with_audio.id})
    assert message =~ "Regenerated regen_clip.mp3"
    assert_received {:tts_text, _text}
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
