defmodule LumenViae.Curation.FilenameOwnershipTest do
  @moduledoc """
  An audio filename belongs to one meditation. A filename reused while
  another meditation's narration is still queued must not be folded into
  that job (which would record the other meditation's words), and a
  meditation whose every voice failed must keep the filename it was meant
  to be recorded under, so it can be repaired later.

  Not async: the stubs are application config.
  """
  use LumenViae.DataCase, async: false
  use Oban.Testing, repo: LumenViae.Repo

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Curation.{AudioJobs, AudioRegeneration, CsvImport}
  alias LumenViae.Curation.Jobs.NarrateMeditation
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Voices
  alias LumenViae.Test.FakeAwsHttpClient

  setup do
    test_pid = self()

    put_env([
      {:lumen_viae, :eleven_labs_api_key, "test-api-key"},
      {:lumen_viae, :audio_retry_base_delay_ms, 1},
      {:lumen_viae, :eleven_labs_req_options, plug: {Req.Test, LumenViae.Audio.ElevenLabs}},
      {:lumen_viae, :fake_aws_test_pid, test_pid},
      {:ex_aws, :http_client, FakeAwsHttpClient},
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    FakeAwsHttpClient.store!()

    {:ok, _} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1},
        actor: admin()
      )

    :ok
  end

  defp csv(content, filename) do
    "mystery_name,content,audio_filename\nThe Annunciation,\"#{content}\",#{filename}\n"
  end

  defp stub_elevenlabs(status) do
    test_pid = self()

    Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
      send(test_pid, :paid)

      case status do
        200 ->
          Plug.Conn.send_resp(conn, 200, "audio-bytes")

        401 ->
          conn
          |> Plug.Conn.put_status(401)
          |> Req.Test.json(%{"detail" => %{"message" => "Invalid API key"}})
      end
    end)
  end

  test "a meditation whose every voice failed keeps its filename, and --only-missing repairs it" do
    stub_elevenlabs(401)

    assert [{:ok, _}] =
             CsvImport.import_string(csv("Behold the handmaid.", "fiat.mp3"), actor: admin())

    assert %{cancelled: 2} = Oban.drain_queue(queue: :elevenlabs)

    [meditation] = Rosary.list_meditations!(actor: admin())
    assert meditation.audio_url == nil
    assert meditation.narration_filename == "fiat.mp3"

    stub_elevenlabs(200)

    results =
      AudioRegeneration.run({:meditation, meditation.id}, only_missing: true, actor: admin())

    assert [{:ok, female}, {:ok, male}] = results
    assert female =~ "Queued voices/female/fiat.mp3"
    assert male =~ "Queued voices/male/fiat.mp3"
    assert %{success: 2} = Oban.drain_queue(queue: :elevenlabs)

    repaired = Rosary.get_meditation!(meditation.id, actor: admin())
    assert repaired.audio_url == "fiat.mp3"
    assert length(Rosary.meditation_narrations(repaired)) == 2
  end

  test "re-importing after Stop import is warned, and never folded into the old row's jobs" do
    stub_elevenlabs(200)

    # The first import is stopped after its rows are written: its narration
    # jobs are still queued.
    assert [{:ok, _}] =
             CsvImport.import_string(csv("The first cut.", "fiat.mp3"), actor: admin())

    # The corrected file is previewed: the filename is held by a job.
    assert {:ok, preview} =
             CsvImport.preview_string(csv("The corrected cut.", "fiat.mp3"), actor: admin())

    assert [%{warnings: warnings}] = preview.rows
    assert Enum.any?(warnings, &(&1 =~ "already queued for recording for another meditation"))

    # Imported anyway, the new row says it got no narration, and why.
    assert [{:warning, message}] =
             CsvImport.import_string(csv("The corrected cut.", "fiat.mp3"), actor: admin())

    assert message =~ "narration could not be queued"
    assert message =~ "already queued for meditation"

    # Only the first row's two jobs exist; the corrected row's text is
    # never recorded under the old row's job.
    assert length(all_enqueued(worker: NarrateMeditation)) == 2
  end

  test "a filename claimed only by narration_filename still counts as taken" do
    stub_elevenlabs(401)
    CsvImport.import_string(csv("Behold the handmaid.", "fiat.mp3"), actor: admin())
    Oban.drain_queue(queue: :elevenlabs)

    assert {:ok, preview} =
             CsvImport.preview_string(csv("Another meditation.", "fiat.mp3"), actor: admin())

    assert [%{warnings: warnings}] = preview.rows
    assert Enum.any?(warnings, &(&1 =~ "already belongs to an existing meditation"))
  end

  test "enqueue refuses a key held by another meditation's job, and returns that job" do
    [mystery] = Rosary.list_mysteries!(actor: admin())
    voice = Voices.get("female")

    {:ok, first} =
      Rosary.create_meditation(%{content: "One.", mystery_id: mystery.id}, actor: admin())

    {:ok, second} =
      Rosary.create_meditation(%{content: "Two.", mystery_id: mystery.id}, actor: admin())

    assert {:ok, :queued} =
             first |> NarrateMeditation.new_for(voice, "shared.mp3") |> AudioJobs.enqueue("b")

    assert {:ok, :already_queued} =
             first |> NarrateMeditation.new_for(voice, "shared.mp3") |> AudioJobs.enqueue("b")

    assert {:error, {:queued_for_another, %Oban.Job{args: args}} = error} =
             second |> NarrateMeditation.new_for(voice, "shared.mp3") |> AudioJobs.enqueue("b")

    assert args["meditation_id"] == first.id
    assert AudioJobs.error_message(error) =~ "already queued for meditation #{first.id}"
  end
end
