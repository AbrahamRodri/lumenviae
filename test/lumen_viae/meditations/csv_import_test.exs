defmodule LumenViae.Meditations.CsvImportTest do
  use LumenViae.DataCase, async: false

  alias LumenViae.Meditations.CsvImport
  alias LumenViae.Rosary
  alias LumenViae.Rosary.{Meditation, MeditationSet, MeditationSetMeditation, Mystery}

  @content "First paragraph of the meditation.\n\nSecond paragraph of the meditation."

  setup do
    {:ok, annunciation} =
      %Mystery{}
      |> Mystery.changeset(%{name: "The Annunciation", category: "joyful", order: 1})
      |> Repo.insert()

    {:ok, visitation} =
      %Mystery{}
      |> Mystery.changeset(%{name: "The Visitation", category: "joyful", order: 2})
      |> Repo.insert()

    %{annunciation: annunciation, visitation: visitation}
  end

  defp csv(headers, rows) do
    ([Enum.join(headers, ",")] ++ rows) |> Enum.join("\n")
  end

  defp quoted(value), do: "\"" <> String.replace(value, "\"", "\"\"") <> "\""

  defp restore_env(key, nil), do: Application.delete_env(:lumen_viae, key)
  defp restore_env(key, value), do: Application.put_env(:lumen_viae, key, value)

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

      results = CsvImport.import_string(content, skip_audio: true)

      assert [{:ok, first}, {:ok, second}] = results
      assert first =~ "The Annunciation"
      assert second =~ "The Visitation"

      assert Repo.aggregate(Meditation, :count) == 2

      set = Repo.get_by!(MeditationSet, name: "Test Set")
      assert set.category == "joyful"
      assert set.labels == ["Intentions", "Saints"]

      orders =
        Repo.all(
          from msm in MeditationSetMeditation,
            where: msm.meditation_set_id == ^set.id,
            order_by: msm.order,
            select: msm.order
        )

      assert orders == [1, 2]
    end

    test "appends after the existing highest order in a set", %{annunciation: mystery} do
      {:ok, set} =
        Rosary.create_meditation_set(%{"name" => "Existing Set", "category" => "joyful"})

      {:ok, meditation} =
        Rosary.create_meditation(%{"content" => @content, "mystery_id" => mystery.id})

      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 5)

      content =
        csv(
          ~w(mystery_name content set_name),
          ["The Visitation,#{quoted(@content)},Existing Set"]
        )

      assert [{:ok, _}] = CsvImport.import_string(content, skip_audio: true)

      max_order =
        Repo.one(
          from msm in MeditationSetMeditation,
            where: msm.meditation_set_id == ^set.id,
            select: max(msm.order)
        )

      assert max_order == 6
    end

    test "dry run validates rows without writing anything" do
      content =
        csv(
          ~w(mystery_name content set_name set_category),
          ["The Annunciation,#{quoted(@content)},Dry Run Set,joyful"]
        )

      assert [{:ok, message}] = CsvImport.import_string(content, dry_run: true)
      assert message =~ "Would create meditation"

      assert Repo.aggregate(Meditation, :count) == 0
      assert Repo.aggregate(MeditationSet, :count) == 0
    end

    test "dry run reports when audio would be skipped" do
      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,#{quoted(@content)},clip.mp3"
        ])

      assert [{:ok, with_audio}] = CsvImport.import_string(content, dry_run: true)
      assert with_audio =~ "(audio)"

      assert [{:ok, skipped}] =
               CsvImport.import_string(content, dry_run: true, skip_audio: true)

      assert skipped =~ "(audio skipped)"
    end

    test "strips a UTF-8 BOM before reading headers" do
      content = "\uFEFF" <> csv(~w(mystery_name content), ["The Annunciation,text"])

      assert [{:ok, _}] = CsvImport.import_string(content, dry_run: true)
    end

    test "skips fully blank rows" do
      content =
        csv(~w(mystery_name content), [
          "The Annunciation,text",
          ",",
          "   ,  ",
          ""
        ])

      results = CsvImport.import_string(content, dry_run: true)
      assert length(results) == 1
    end

    test "rejects unknown columns instead of silently ignoring them" do
      content = csv(~w(mystery_name content set_lables), ["The Annunciation,text,Saints"])

      assert [{:error, message}] = CsvImport.import_string(content, dry_run: true)
      assert message =~ "unknown column"
      assert message =~ "set_lables"
      assert message =~ "Allowed columns"
    end

    test "rejects a file without the required columns" do
      content = csv(~w(title content), ["Fiat,text"])

      assert [{:error, message}] = CsvImport.import_string(content, dry_run: true)
      assert message =~ "missing required column"
      assert message =~ "mystery_name"
    end

    test "rejects duplicate header columns" do
      content = csv(~w(mystery_name content content), ["The Annunciation,text,text"])

      assert [{:error, message}] = CsvImport.import_string(content, dry_run: true)
      assert message =~ "duplicate column"
    end

    test "errors on rows whose field count does not match the header" do
      content = csv(~w(mystery_name content), ["The Annunciation,text,unexpected extra"])

      assert [{:error, message}] = CsvImport.import_string(content, dry_run: true)
      assert message =~ "3 fields but the header has 2"
    end

    test "errors on rows that reuse the same audio_filename" do
      content =
        csv(~w(mystery_name content audio_filename), [
          "The Annunciation,text,clip.mp3",
          "The Visitation,text,clip.mp3"
        ])

      results = CsvImport.import_string(content, dry_run: true)

      assert [{:error, first}, {:error, second}] = results
      assert first =~ "duplicate audio_filename 'clip.mp3'"
      assert second =~ "duplicate audio_filename 'clip.mp3'"
    end
  end

  describe "audio generation failures" do
    setup do
      original_key = Application.get_env(:lumen_viae, :eleven_labs_api_key)
      original_req = Application.get_env(:lumen_viae, :eleven_labs_req_options)
      original_delay = Application.get_env(:lumen_viae, :audio_retry_base_delay_ms)

      Application.put_env(:lumen_viae, :eleven_labs_api_key, "test-api-key")
      Application.put_env(:lumen_viae, :audio_retry_base_delay_ms, 1)

      Application.put_env(:lumen_viae, :eleven_labs_req_options,
        plug: {Req.Test, LumenViae.Audio.ElevenLabs}
      )

      on_exit(fn ->
        restore_env(:eleven_labs_api_key, original_key)
        restore_env(:eleven_labs_req_options, original_req)
        restore_env(:audio_retry_base_delay_ms, original_delay)
      end)

      :ok
    end

    test "still creates the meditation and reports a warning after retries run out" do
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

      results =
        CsvImport.import_string(content,
          progress: fn event -> send(test_pid, {:progress, event}) end
        )

      assert [{:warning, message}] = results
      assert message =~ "Created meditation for The Annunciation"
      assert message =~ "audio generation failed"
      assert message =~ "server error"

      meditation = Repo.one!(Meditation)
      assert meditation.audio_url == nil

      # All three attempts hit the API, with two retry notifications.
      assert_received :api_called
      assert_received :api_called
      assert_received :api_called
      refute_received :api_called
      assert_received {:progress, {:row_audio_retry, 1, 1, "clip.mp3", 2, 3}}
      assert_received {:progress, {:row_audio_retry, 1, 1, "clip.mp3", 3, 3}}
    end

    test "does not retry when ElevenLabs rejects the API key" do
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

      results =
        CsvImport.import_string(content,
          progress: fn event -> send(test_pid, {:progress, event}) end
        )

      assert [{:warning, message}] = results
      assert message =~ "rejected the API key"

      assert_received :api_called
      refute_received :api_called
      refute_received {:progress, {:row_audio_retry, _, _, _, _, _}}
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

      assert {:ok, preview} = CsvImport.preview_string(content)
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

      assert {:ok, preview} = CsvImport.preview_string(content)
      assert preview.error_count == 2

      [first, second] = preview.rows
      assert Enum.any?(first.errors, &(&1 =~ "mystery not found"))
      assert Enum.any?(first.errors, &(&1 =~ "duplicate audio_filename"))
      assert Enum.any?(second.errors, &(&1 =~ "duplicate audio_filename"))
    end

    test "warns when an audio_filename would overwrite an existing meditation's audio",
         %{annunciation: mystery} do
      {:ok, _} =
        Rosary.create_meditation(%{
          "content" => @content,
          "mystery_id" => mystery.id,
          "audio_url" => "existing.mp3"
        })

      content =
        csv(~w(mystery_name content audio_filename), [
          "The Visitation,text,existing.mp3"
        ])

      assert {:ok, preview} = CsvImport.preview_string(content)
      [row] = preview.rows
      assert row.errors == []
      assert Enum.any?(row.warnings, &(&1 =~ "overwrite its audio"))
    end

    test "returns a file-level error for unusable files" do
      assert {:error, message} = CsvImport.preview_string("")
      assert message =~ "empty"

      assert {:error, message} = CsvImport.preview_string("mystery_name,content")
      assert message =~ "no data rows"
    end
  end
end
