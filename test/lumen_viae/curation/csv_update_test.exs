defmodule LumenViae.Curation.CsvUpdateTest do
  use LumenViae.DataCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Curation.CsvUpdate
  alias LumenViae.Rosary

  @old "The old text.\n\nIts second paragraph."
  @new "The new text, cut afresh. {pause:2}\n\nA second paragraph, and a third sentence."

  setup do
    {:ok, mystery} =
      Rosary.create_mystery(%{name: "The Crowning with Thorns", category: "sorrowful", order: 3})

    {:ok, set} = Rosary.create_meditation_set(%{"name" => "Set", "category" => "sorrowful"})

    {:ok, meditation} =
      Rosary.create_meditation(%{
        "content" => @old,
        "mystery_id" => mystery.id,
        "title" => "Not One Member Spared",
        "source" => "Old source",
        "audio_url" => "sorrowful_chrysostom_3.mp3"
      })

    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)

    {:ok, _} =
      Rosary.record_narration(meditation, "male", "voices/male/sorrowful_chrysostom_3.mp3")

    %{meditation: meditation, set: set}
  end

  defp csv(rows) do
    header = "meditation_id,title,content,source\n"
    header <> Enum.map_join(rows, "\n", fn cells -> Enum.map_join(cells, ",", &quoted/1) end)
  end

  defp quoted(value), do: "\"" <> String.replace(value, "\"", "\"\"") <> "\""

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
      |> Plug.Conn.send_resp(200, "new-audio")
    end)
  end

  test "dry run describes the change and writes nothing", %{meditation: meditation} do
    results =
      CsvUpdate.update_string(
        csv([[to_string(meditation.id), "Bear Them in Our Mind", @new, "New source"]]),
        dry_run: true
      )

    assert [{:ok, message}] = results
    assert message =~ "Would update meditation #{meditation.id} (Not One Member Spared)"
    assert message =~ ~s(title "Not One Member Spared" -> "Bear Them in Our Mind")
    assert message =~ "6 -> 12 words"
    assert message =~ "1 custom pause(s)"
    assert message =~ "new source"

    reloaded = Rosary.get_meditation!(meditation.id)
    assert reloaded.content == @old
    assert reloaded.title == "Not One Member Spared"
  end

  test "updates the text in place and re-records every voice", %{
    meditation: meditation,
    set: set
  } do
    stub_apis()

    results =
      CsvUpdate.update_string(
        csv([[to_string(meditation.id), "Bear Them in Our Mind", @new, "New source"]])
      )

    assert [{:ok, message}] = results
    assert message =~ "Updated meditation #{meditation.id}"
    assert message =~ "regenerated its narration"

    reloaded = Rosary.get_meditation!(meditation.id)
    assert reloaded.title == "Bear Them in Our Mind"
    assert reloaded.source == "New source"

    assert reloaded.content ==
             "The new text, cut afresh.\n\nA second paragraph, and a third sentence."

    assert [%{"seconds" => 2.0}] = reloaded.tts_annotations
    assert reloaded.audio_url == "sorrowful_chrysostom_3.mp3"

    # Same id, still in its set, now recorded in both voices from the new
    # words - the custom pause replacing the paragraph break's default.
    assert [%{id: id}] = Rosary.list_meditations_in_set(set.id)
    assert id == meditation.id

    assert Enum.map(Rosary.meditation_narrations(reloaded), & &1.voice.slug) == ["female", "male"]

    assert_received {:tts_text, "/v1/text-to-speech/Z3R5wn05IrDiVCyEkUrK",
                     "The new text, cut afresh. [pause] A second paragraph, and a third sentence."}

    assert_received {:tts_text, "/v1/text-to-speech/RTFg9niKcgGLDwa3RFlz",
                     ~s(The new text, cut afresh. <break time="2s" /> A second paragraph, and a third sentence.)}
  end

  test "an empty optional cell leaves that column alone", %{meditation: meditation} do
    results =
      CsvUpdate.update_string(csv([[to_string(meditation.id), "", @new, ""]]), skip_audio: true)

    assert [{:ok, message}] = results
    assert message =~ "audio not regenerated"
    reloaded = Rosary.get_meditation!(meditation.id)
    assert reloaded.title == "Not One Member Spared"
    assert reloaded.source == "Old source"
    assert reloaded.content =~ "The new text"
  end

  test "reports a narration failure as a warning after writing the text", %{
    meditation: meditation
  } do
    stub_apis()

    Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
      conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"detail" => %{"message" => "bad key"}})
    end)

    assert [{:warning, message}] =
             CsvUpdate.update_string(csv([[to_string(meditation.id), "", @new, ""]]))

    assert message =~ "narration failed"
    assert Rosary.get_meditation!(meditation.id).content =~ "The new text"
  end

  test "rejects unknown ids, bad markup and unknown columns" do
    assert [{:error, missing}] = CsvUpdate.update_string(csv([["999999", "", @new, ""]]))
    assert missing =~ "Meditation not found: id 999999"

    assert [{:error, columns}] =
             CsvUpdate.update_string("meditation_id,content,mystery_name\n1,x,y")

    assert columns =~ "unknown column(s): mystery_name"
  end

  test "rejects a literal break tag", %{meditation: meditation} do
    assert [{:error, message}] =
             CsvUpdate.update_string(
               csv([
                 [to_string(meditation.id), "", "Text <break time=\"1s\" /> more.\n\nMore.", ""]
               ])
             )

    assert message =~ "literal <break tag"
  end
end
