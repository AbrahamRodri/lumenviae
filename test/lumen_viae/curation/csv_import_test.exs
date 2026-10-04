defmodule LumenViae.Curation.CsvImportTest do
  use LumenViae.DataCase, async: false

  alias LumenViae.Curation.CsvImport
  alias LumenViae.Rosary
  alias LumenViae.Test.EnvStub

  @content "First paragraph of the meditation.\n\nSecond paragraph of the meditation."

  setup do
    {:ok, annunciation} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1},
        actor: admin()
      )

    {:ok, visitation} =
      Rosary.create_mystery(%{name: "The Visitation", category: "joyful", order: 2},
        actor: admin()
      )

    %{annunciation: annunciation, visitation: visitation}
  end

  defp csv(headers, rows) do
    ([Enum.join(headers, ",")] ++ rows) |> Enum.join("\n")
  end

  defp quoted(value), do: "\"" <> String.replace(value, "\"", "\"\"") <> "\""

  describe "import_string/2" do
    test "creates meditations and attaches them to a new set in order" do
      content =
        csv(
          ~w(mystery_name title content set_name set_category set_labels),
          [
            "The Annunciation,Fiat,#{quoted(@content)},Test Set,joyful,Intentions|Saints",
            "The Visitation,Charity,#{quoted(@content)},Test Set,joyful,Intentions|Saints"
          ]
        )

      results = CsvImport.import_string(content, skip_audio: true, actor: admin())

      assert [{:ok, first}, {:ok, second}] = results
      assert first =~ "The Annunciation"
      assert second =~ "The Visitation"

      assert Rosary.count_meditations(actor: admin()) == 2

      set = Rosary.get_meditation_set_by_name("Test Set", nil, actor: admin())
      assert set.category == "joyful"
      assert set.labels == ["Intentions", "Saints"]

      assert Rosary.get_meditation_set_with_ordered_meditations!(set.id, actor: admin()).meditations
             |> Enum.map(& &1.mystery.name) == ["The Annunciation", "The Visitation"]
    end

    test "appends after the existing highest order in a set", %{annunciation: mystery} do
      {:ok, set} =
        Rosary.create_meditation_set(%{"name" => "Existing Set", "category" => "joyful"},
          actor: admin()
        )

      {:ok, meditation} =
        Rosary.create_meditation(%{"content" => @content, "mystery_id" => mystery.id},
          actor: admin()
        )

      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 5, actor: admin())

      content =
        csv(
          ~w(mystery_name content set_name),
          ["The Visitation,#{quoted(@content)},Existing Set"]
        )

      assert [{:ok, _}] = CsvImport.import_string(content, skip_audio: true, actor: admin())

      assert Rosary.next_order_in_set(set.id, actor: admin()) == 7
    end

    test "dry run validates rows without writing anything" do
      content =
        csv(
          ~w(mystery_name content set_name set_category),
          ["The Annunciation,#{quoted(@content)},Dry Run Set,joyful"]
        )

      assert [{:ok, message}] = CsvImport.import_string(content, dry_run: true, actor: admin())
      assert message =~ "Would create meditation"

      assert Rosary.count_meditations(actor: admin()) == 0
      assert Rosary.count_meditation_sets(actor: admin()) == 0
    end

    test "dry run reports when audio would be skipped" do
      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@content)},clip.mp3"
        ])

      assert [{:ok, with_audio}] = CsvImport.import_string(content, dry_run: true, actor: admin())
      assert with_audio =~ "(audio)"

      assert [{:ok, skipped}] =
               CsvImport.import_string(content, dry_run: true, skip_audio: true, actor: admin())

      assert skipped =~ "(audio skipped)"
    end

    test "strips a UTF-8 BOM before reading headers" do
      content = "\uFEFF" <> csv(~w(mystery_name content), ["The Annunciation,text"])

      assert [{:ok, _}] = CsvImport.import_string(content, dry_run: true, actor: admin())
    end

    test "skips fully blank rows" do
      content =
        csv(~w(mystery_name content), [
          "The Annunciation,text",
          ",",
          "   ,  ",
          ""
        ])

      results = CsvImport.import_string(content, dry_run: true, actor: admin())
      assert length(results) == 1
    end

    test "writes the set's own byline from set_author and set_source" do
      content =
        csv(
          ~w(mystery_name content set_name set_category set_author set_source),
          [
            "The Annunciation,#{quoted(@content)},Emmerich Set,joyful,Bl. Anne Catherine Emmerich,The Dolorous Passion",
            "The Visitation,#{quoted(@content)},Emmerich Set,joyful,Bl. Anne Catherine Emmerich,The Dolorous Passion"
          ]
        )

      assert Enum.all?(
               CsvImport.import_string(content, skip_audio: true, actor: admin()),
               &match?({:ok, _}, &1)
             )

      set = Rosary.get_meditation_set_by_name("Emmerich Set", nil, actor: admin())

      assert set.author == "Bl. Anne Catherine Emmerich"
      assert set.source == "The Dolorous Passion"
    end

    # Create-only, like set_description: re-importing into a set must not
    # rewrite what a curator has since edited in the admin.
    test "leaves an existing set's byline alone" do
      {:ok, set} =
        Rosary.create_meditation_set(
          %{
            name: "Existing Set",
            category: "joyful",
            author: "Curated By Hand"
          },
          actor: admin()
        )

      content =
        csv(
          ~w(mystery_name content set_name set_category set_author),
          ["The Annunciation,#{quoted(@content)},Existing Set,joyful,From The CSV"]
        )

      assert [{:ok, _}] = CsvImport.import_string(content, skip_audio: true, actor: admin())

      assert Rosary.get_meditation_set_by_name("Existing Set", nil, actor: admin()).author ==
               "Curated By Hand"

      assert Rosary.get_meditation_set!(set.id, actor: admin()).author == "Curated By Hand"
    end

    test "rejects unknown columns instead of silently ignoring them" do
      content = csv(~w(mystery_name content set_lables), ["The Annunciation,text,Saints"])

      assert [{:error, message}] = CsvImport.import_string(content, dry_run: true, actor: admin())
      assert message =~ "unknown column"
      assert message =~ "set_lables"
      assert message =~ "Allowed columns"
    end

    test "rejects a file without the required columns" do
      content = csv(~w(title content), ["Fiat,text"])

      assert [{:error, message}] = CsvImport.import_string(content, dry_run: true, actor: admin())
      assert message =~ "missing required column"
      assert message =~ "mystery_name"
    end

    test "rejects duplicate header columns" do
      content = csv(~w(mystery_name content content), ["The Annunciation,text,text"])

      assert [{:error, message}] = CsvImport.import_string(content, dry_run: true, actor: admin())
      assert message =~ "duplicate column"
    end

    test "errors on rows whose field count does not match the header" do
      content = csv(~w(mystery_name content), ["The Annunciation,text,unexpected extra"])

      assert [{:error, message}] = CsvImport.import_string(content, dry_run: true, actor: admin())
      assert message =~ "3 fields but the header has 2"
    end

    test "errors on rows that reuse the same audio_filename" do
      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,text,clip.mp3",
          "The Visitation,text,clip.mp3"
        ])

      results = CsvImport.import_string(content, dry_run: true, actor: admin())

      assert [{:error, first}, {:error, second}] = results
      assert first =~ "duplicate audio_filename 'clip.mp3'"
      assert second =~ "duplicate audio_filename 'clip.mp3'"
    end
  end

  describe "sets that share a name across categories" do
    setup do
      {:ok, mystery} =
        Rosary.create_mystery(
          %{
            name: "The Prophecy of Simeon",
            category: "seven_sorrows",
            order: 1
          },
          actor: admin()
        )

      {:ok, joyful} =
        Rosary.create_meditation_set(%{"name" => "Faber", "category" => "joyful"}, actor: admin())

      %{joyful: joyful, mystery: mystery}
    end

    test "a row with a category attaches to the set of that category, creating it", %{
      joyful: joyful
    } do
      content =
        csv(~w(mystery_name content set_name set_category), [
          "The Prophecy of Simeon,#{quoted(@content)},Faber,seven_sorrows"
        ])

      assert [{:ok, message}] = CsvImport.import_string(content, skip_audio: true, actor: admin())
      assert message =~ "[set: Faber]"

      sorrows = Rosary.get_meditation_set_by_name("Faber", "seven_sorrows", actor: admin())
      assert sorrows.id != joyful.id
      assert Rosary.list_meditations_in_set(joyful.id, actor: admin()) == []
      assert length(Rosary.list_meditations_in_set(sorrows.id, actor: admin())) == 1
    end

    test "a row naming an ambiguous set without a category is refused" do
      {:ok, _} =
        Rosary.create_meditation_set(%{"name" => "Faber", "category" => "sorrowful"},
          actor: admin()
        )

      content =
        csv(~w(mystery_name content set_name), [
          "The Prophecy of Simeon,#{quoted(@content)},Faber"
        ])

      assert [{:error, message}] =
               CsvImport.import_string(content, skip_audio: true, actor: admin())

      assert message =~ "exists in more than one category"
      assert Rosary.count_meditations(actor: admin()) == 0
    end
  end

  describe "a mystery name that stands in two categories" do
    # The Crucifixion is the fifth Sorrowful Mystery and the fifth sorrow of
    # the Seven Sorrows, which sort first.
    setup do
      {:ok, sorrowful} =
        Rosary.create_mystery(%{name: "The Crucifixion", category: "sorrowful", order: 5},
          actor: admin()
        )

      {:ok, sorrow} =
        Rosary.create_mystery(%{name: "The Crucifixion", category: "seven_sorrows", order: 5},
          actor: admin()
        )

      %{sorrowful: sorrowful, sorrow: sorrow}
    end

    defp mystery_of_only_meditation do
      [meditation] = Rosary.list_meditations!(actor: admin())
      meditation.mystery_id
    end

    test "goes to the mystery of the row's set_category", %{sorrowful: sorrowful} do
      content =
        csv(~w(mystery_name content set_name set_category), [
          "The Crucifixion,#{quoted(@content)},Liguori,sorrowful"
        ])

      assert [{:ok, _}] = CsvImport.import_string(content, skip_audio: true, actor: admin())
      assert mystery_of_only_meditation() == sorrowful.id
    end

    test "or else to the mystery of the existing set's category", %{sorrow: sorrow} do
      {:ok, _} =
        Rosary.create_meditation_set(%{"name" => "Agreda", "category" => "seven_sorrows"},
          actor: admin()
        )

      content =
        csv(~w(mystery_name content set_name), [
          "The Crucifixion,#{quoted(@content)},Agreda"
        ])

      assert [{:ok, _}] = CsvImport.import_string(content, skip_audio: true, actor: admin())
      assert mystery_of_only_meditation() == sorrow.id
    end

    test "is refused when nothing on the row says which" do
      content = csv(~w(mystery_name content), ["The Crucifixion,#{quoted(@content)}"])

      assert [{:error, message}] =
               CsvImport.import_string(content, skip_audio: true, actor: admin())

      assert message =~
               "mystery name 'The Crucifixion' is in more than one category; add set_category"

      assert Rosary.count_meditations(actor: admin()) == 0
    end

    test "the preview says the same" do
      content =
        csv(~w(mystery_name content set_name set_category), [
          "The Crucifixion,#{quoted(@content)},Liguori,sorrowful",
          "The Crucifixion,#{quoted(@content)},,"
        ])

      assert {:ok, %{rows: [chosen, ambiguous]}} =
               CsvImport.preview_string(content, actor: admin())

      assert chosen.mystery_ok
      assert chosen.errors == []
      refute ambiguous.mystery_ok

      assert ambiguous.errors == [
               "mystery name 'The Crucifixion' is in more than one category; add set_category"
             ]
    end
  end

  describe "audio generation failures" do
    setup do
      test_pid = self()

      EnvStub.put_env([
        {:lumen_viae, :eleven_labs_api_key, "test-api-key"},
        {:lumen_viae, :audio_retry_base_delay_ms, 1},
        {:lumen_viae, :eleven_labs_req_options, plug: {Req.Test, LumenViae.Audio.ElevenLabs}},
        {:lumen_viae, :fake_aws_test_pid, test_pid},
        {:ex_aws, :http_client, LumenViae.Test.FakeAwsHttpClient},
        {:ex_aws, :access_key_id, "test-key"},
        {:ex_aws, :secret_access_key, "test-secret"}
      ])

      LumenViae.Test.FakeAwsHttpClient.store!()
      :ok
    end

    test "a failure ElevenLabs did not charge for is retried later, and the meditation stands" do
      test_pid = self()

      Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
        send(test_pid, :api_called)

        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"detail" => "internal error"})
      end)

      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@content)},clip.mp3"
        ])

      assert [{:ok, message}] =
               CsvImport.import_string(content, voices: ["female"], actor: admin())

      assert message =~ "Created meditation for The Annunciation"
      assert message =~ "narration queued: female"

      # One attempt, which fails and is left to Oban to retry with backoff.
      assert %{failure: 1} = Oban.drain_queue(queue: :elevenlabs)
      assert_received :api_called
      refute_received :api_called

      [meditation] = Rosary.list_meditations!(actor: admin())
      assert meditation.audio_url == nil
      assert Rosary.meditation_narrations(meditation) == []
    end

    test "a rejected API key cancels the job: a retry could not succeed" do
      test_pid = self()

      Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
        send(test_pid, :api_called)

        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"detail" => %{"message" => "Invalid API key"}})
      end)

      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@content)},clip.mp3"
        ])

      assert [{:ok, _}] = CsvImport.import_string(content, voices: ["female"], actor: admin())
      assert %{cancelled: 1} = Oban.drain_queue(queue: :elevenlabs)

      assert_received :api_called
      refute_received :api_called
    end

    test "a timeout may have been charged for, so it is cancelled, never retried" do
      test_pid = self()

      Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
        send(test_pid, :api_called)
        Req.Test.transport_error(conn, :timeout)
      end)

      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@content)},clip.mp3"
        ])

      assert [{:ok, _}] = CsvImport.import_string(content, voices: ["female"], actor: admin())
      assert %{cancelled: 1} = Oban.drain_queue(queue: :elevenlabs)

      assert_received :api_called
      refute_received :api_called

      [job] = Oban.Job |> LumenViae.Repo.all()
      assert job.state == "cancelled"
      assert hd(job.errors)["error"] =~ "may have charged"
    end

    test "a dry run enqueues nothing" do
      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@content)},clip.mp3"
        ])

      assert [{:ok, _}] = CsvImport.import_string(content, dry_run: true, actor: admin())
      assert LumenViae.Repo.aggregate(Oban.Job, :count) == 0
    end

    test "raises on an unknown voice rather than importing without it" do
      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@content)},clip.mp3"
        ])

      assert_raise ArgumentError, ~r/unknown voice: tenor/, fn ->
        CsvImport.import_string(content, voices: ["tenor"], actor: admin())
      end
    end
  end

  describe "pause markers" do
    @marked_content "First paragraph of the meditation.\n\n{pause:2.5}\n\nSecond paragraph of the meditation."

    test "strips markers from stored content and persists annotations" do
      content =
        csv(~w(mystery_name content), ["The Annunciation,#{quoted(@marked_content)}"])

      assert [{:ok, _}] = CsvImport.import_string(content, skip_audio: true, actor: admin())

      [meditation] = Rosary.list_meditations!(actor: admin())

      # Stored content is the imported content minus the marker; the pause
      # survives only as an annotation.
      assert meditation.content == @content
      refute meditation.content =~ "pause"

      offset = String.length("First paragraph of the meditation.")
      assert meditation.tts_annotations == [%{"offset" => offset, "seconds" => 2.5}]
    end

    test "dry run validates marker content without writing" do
      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@marked_content)},clip.mp3"
        ])

      assert [{:ok, message}] = CsvImport.import_string(content, dry_run: true, actor: admin())
      assert message =~ "Would create meditation"
      assert message =~ "(audio)"

      assert Rosary.count_meditations(actor: admin()) == 0
    end

    test "rejects malformed pause markers" do
      content =
        csv(~w(mystery_name content), [
          "The Annunciation,#{quoted("Pause {pause:soon} here.")}"
        ])

      assert [{:error, message}] = CsvImport.import_string(content, dry_run: true, actor: admin())
      assert message =~ "Invalid content for 'The Annunciation'"
      assert message =~ "invalid pause marker"

      assert [{:error, _}] = CsvImport.import_string(content, skip_audio: true, actor: admin())
      assert Rosary.count_meditations(actor: admin()) == 0
    end

    test "rejects literal <break tags in content" do
      content =
        csv(~w(mystery_name content), [
          "The Annunciation,#{quoted(~s(Pause <break time="1s" /> here.))}"
        ])

      assert [{:error, message}] =
               CsvImport.import_string(content, skip_audio: true, actor: admin())

      assert message =~ "<break"

      assert Rosary.count_meditations(actor: admin()) == 0
    end

    test "preview counts pauses against the cleaned content" do
      content =
        csv(~w(mystery_name content), [
          "The Annunciation,#{quoted(@marked_content)}",
          "The Visitation,#{quoted("Broken {pause:oops} marker.")}"
        ])

      assert {:ok, preview} = CsvImport.preview_string(content, actor: admin())
      assert [clean_row, broken_row] = preview.rows

      assert clean_row.errors == []
      assert clean_row.pause_count == 1
      assert clean_row.content_chars == String.length(@content)
      assert clean_row.paragraphs == 2
      refute clean_row.content_excerpt =~ "pause"

      assert Enum.any?(broken_row.errors, &(&1 =~ "invalid pause marker"))
      assert broken_row.pause_count == 0
    end
  end

  describe "audio generation with pause tags" do
    setup do
      test_pid = self()

      EnvStub.put_env([
        {:lumen_viae, :eleven_labs_api_key, "test-api-key"},
        {:lumen_viae, :audio_retry_base_delay_ms, 1},
        {:lumen_viae, :eleven_labs_req_options, plug: {Req.Test, LumenViae.Audio.ElevenLabs}},
        {:lumen_viae, :fake_aws_test_pid, test_pid},
        {:ex_aws, :http_client, LumenViae.Test.FakeAwsHttpClient},
        {:ex_aws, :access_key_id, "test-key"},
        {:ex_aws, :secret_access_key, "test-secret"}
      ])

      %{test_pid: test_pid}
    end

    defp stub_success(test_pid) do
      Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        send(
          test_pid,
          {:tts_request, conn.request_path, decoded["model_id"], decoded["text"],
           decoded["voice_settings"]}
        )

        conn
        |> Plug.Conn.put_resp_content_type("audio/mpeg")
        |> Plug.Conn.send_resp(200, "audio-bytes")
      end)
    end

    test "records every configured voice under its own prefix, each on its own model",
         %{test_pid: test_pid} do
      stub_success(test_pid)

      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@marked_content)},clip.mp3"
        ])

      assert [{:ok, message}] = CsvImport.import_string(content, actor: admin())
      assert message =~ "(narration queued: female, male)"

      # Written straight away, with no audio_url until a recording lands.
      [meditation] = Rosary.list_meditations!(actor: admin())
      assert meditation.audio_url == nil
      assert %{success: 2} = Oban.drain_queue(queue: :elevenlabs)

      # One request per voice, each to that voice's ElevenLabs id on that
      # voice's model, with the custom 2.5s pause (which replaces the
      # paragraph break's default) written in that model's syntax: a v3
      # audio tag for the female voice, an SSML break tag for the male.
      v3_text =
        "First paragraph of the meditation. [long pause] Second paragraph of the meditation."

      v2_text =
        ~s(First paragraph of the meditation. <break time="2.5s" /> Second paragraph of the meditation.)

      assert_received {:tts_request, "/v1/text-to-speech/Z3R5wn05IrDiVCyEkUrK", "eleven_v3",
                       ^v3_text, %{"stability" => 0.5, "similarity_boost" => 0.75}}

      assert_received {:tts_request, "/v1/text-to-speech/RTFg9niKcgGLDwa3RFlz",
                       "eleven_multilingual_v2", ^v2_text,
                       %{"stability" => 0.5, "similarity_boost" => 0.75, "style" => 0.5}}

      refute_received {:tts_request, _, _, _, _}

      assert_received {:aws_request, :put, female_url, "audio-bytes"}
      assert_received {:aws_request, :put, male_url, "audio-bytes"}

      assert Enum.sort([female_url, male_url]) |> Enum.map(&URI.parse(&1).path) ==
               [
                 "/lumenviae-audio/voices/female/clip.mp3",
                 "/lumenviae-audio/voices/male/clip.mp3"
               ]

      [meditation] = Rosary.list_meditations!(actor: admin())
      assert meditation.audio_url == "clip.mp3"
      assert meditation.content == @content
      refute meditation.content =~ "pause"
      refute meditation.content =~ "<break"

      assert Enum.map(Rosary.meditation_narrations(meditation), &{&1.voice.slug, &1.s3_key}) ==
               [{"female", "voices/female/clip.mp3"}, {"male", "voices/male/clip.mp3"}]
    end

    test "a voice configured on v3 gets audio tags whatever the other voices use",
         %{test_pid: test_pid} do
      EnvStub.put_env(:lumen_viae, :narration_voices, [
        %{
          slug: "male",
          name: "Male",
          eleven_labs_voice_id: "m",
          model_id: "eleven_multilingual_v2"
        },
        %{
          slug: "female",
          name: "Female",
          eleven_labs_voice_id: "f",
          model_id: "eleven_v3",
          default: true
        }
      ])

      stub_success(test_pid)

      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@marked_content)},clip.mp3"
        ])

      assert [{:ok, _}] = CsvImport.import_string(content, voices: ["female"], actor: admin())
      Oban.drain_queue(queue: :elevenlabs)

      assert_received {:tts_request, "/v1/text-to-speech/f", "eleven_v3", speech_text, _}
      assert speech_text =~ "[long pause]"
      refute_received {:tts_request, _, _, _, _}
    end

    test "a voice that fails still leaves the others recorded" do
      Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
        if String.ends_with?(conn.request_path, "RTFg9niKcgGLDwa3RFlz") do
          conn
          |> Plug.Conn.put_status(401)
          |> Req.Test.json(%{"detail" => %{"message" => "Invalid API key"}})
        else
          conn
          |> Plug.Conn.put_resp_content_type("audio/mpeg")
          |> Plug.Conn.send_resp(200, "audio-bytes")
        end
      end)

      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@content)},clip.mp3"
        ])

      assert [{:ok, _}] = CsvImport.import_string(content, actor: admin())
      assert %{success: 1, cancelled: 1} = Oban.drain_queue(queue: :elevenlabs)

      [meditation] = Rosary.list_meditations!(actor: admin())
      assert meditation.audio_url == "clip.mp3"
      assert [%{voice: %{slug: "female"}}] = Rosary.meditation_narrations(meditation)
    end
  end

  describe "preview_string/1" do
    test "summarizes rows, sets, and audio" do
      content =
        csv(
          ~w(mystery_name title content set_name set_category set_labels audio_filename),
          [
            "The Annunciation,Fiat,#{quoted(@content)},Preview Set,joyful,Intentions,clip_1.mp3",
            "The Visitation,Charity,#{quoted(@content)},Preview Set,joyful,Intentions,clip_2.mp3"
          ]
        )

      assert {:ok, preview} = CsvImport.preview_string(content, actor: admin())
      assert preview.total == 2
      assert preview.valid_count == 2
      assert preview.error_count == 0
      assert preview.audio_count == 2
      assert preview.new_sets == ["Preview Set"]
      assert preview.existing_sets == []

      [row | _] = preview.rows
      assert row.mystery_ok
      assert row.set_status == :new
      assert row.set_labels == ["Intentions"]
    end

    test "flags unknown mysteries and duplicate audio filenames" do
      content =
        csv(~w(mystery_name content audio_filename), [
          "Not A Mystery,text,clip.mp3",
          "The Visitation,text,clip.mp3"
        ])

      assert {:ok, preview} = CsvImport.preview_string(content, actor: admin())
      assert preview.error_count == 2

      [first, second] = preview.rows
      assert Enum.any?(first.errors, &(&1 =~ "mystery not found"))
      assert Enum.any?(first.errors, &(&1 =~ "duplicate audio_filename"))
      assert Enum.any?(second.errors, &(&1 =~ "duplicate audio_filename"))
    end

    test "warns when an audio_filename would overwrite an existing meditation's audio",
         %{annunciation: mystery} do
      {:ok, _} =
        Rosary.create_meditation(
          %{
            "content" => @content,
            "mystery_id" => mystery.id,
            "audio_url" => "existing.mp3"
          },
          actor: admin()
        )

      content =
        csv(~w(mystery_name content audio_filename), [
          "The Visitation,text,existing.mp3"
        ])

      assert {:ok, preview} = CsvImport.preview_string(content, actor: admin())
      [row] = preview.rows
      assert row.errors == []
      assert Enum.any?(row.warnings, &(&1 =~ "overwrite its audio"))
    end

    test "returns a file-level error for unusable files" do
      assert {:error, message} = CsvImport.preview_string("", actor: admin())
      assert message =~ "empty"

      assert {:error, message} = CsvImport.preview_string("mystery_name,content", actor: admin())
      assert message =~ "no data rows"
    end
  end
end
