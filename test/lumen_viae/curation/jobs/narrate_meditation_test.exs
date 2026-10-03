defmodule LumenViae.Curation.Jobs.NarrateMeditationTest do
  @moduledoc """
  A narration job pays ElevenLabs at most once for a clip, however often it
  is retried or enqueued. The fake S3 client remembers what was uploaded
  and with what metadata, so these tests can watch the job decide.

  Not async: the stubs are application config.
  """
  use LumenViae.DataCase, async: false
  use Oban.Testing, repo: LumenViae.Repo

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Curation.AudioJobs
  alias LumenViae.Curation.Jobs.NarrateMeditation
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Voices
  alias LumenViae.Test.FakeAwsHttpClient

  @content "First paragraph.\n\nSecond paragraph."
  @key "voices/female/narrated.mp3"

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

    Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
      send(test_pid, :paid)

      conn
      |> Plug.Conn.put_resp_content_type("audio/mpeg")
      |> Plug.Conn.send_resp(200, "audio-bytes")
    end)

    {:ok, mystery} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1},
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(%{"content" => @content, "mystery_id" => mystery.id},
        actor: admin()
      )

    %{meditation: meditation, voice: Voices.get("female")}
  end

  defp enqueue(meditation, voice, opts \\ []) do
    meditation
    |> NarrateMeditation.new_for(voice, "narrated.mp3", opts)
    |> AudioJobs.enqueue(Keyword.get(opts, :batch, "test-batch"))
  end

  defp run, do: Oban.drain_queue(queue: :elevenlabs)

  defp fingerprint(meditation, voice) do
    meditation.content
    |> LumenViae.Audio.Pipeline.speech_text(meditation.tts_annotations, voice)
    |> LumenViae.Audio.Recording.fingerprint(voice)
  end

  defp paid_count(count \\ 0) do
    receive do
      :paid -> paid_count(count + 1)
    after
      0 -> count
    end
  end

  test "records, uploads, puts it on record, and sets the audio_url", %{
    meditation: meditation,
    voice: voice
  } do
    assert {:ok, :queued} = enqueue(meditation, voice)
    assert %{success: 1} = run()
    assert paid_count() == 1

    reloaded = Rosary.get_meditation!(meditation.id, actor: admin())
    assert reloaded.audio_url == "narrated.mp3"
    assert [%{s3_key: @key}] = Rosary.meditation_narrations(reloaded)
  end

  test "a second enqueue while the first waits is the same job", %{
    meditation: meditation,
    voice: voice
  } do
    assert {:ok, :queued} = enqueue(meditation, voice)
    assert {:ok, :already_queued} = enqueue(meditation, voice)
    assert [_one] = all_enqueued(worker: NarrateMeditation)

    run()
    assert paid_count() == 1
  end

  test "an enqueue after the recording finished pays for nothing", %{
    meditation: meditation,
    voice: voice
  } do
    enqueue(meditation, voice)
    run()
    assert paid_count() == 1

    assert {:ok, :queued} = enqueue(meditation, voice)
    assert %{success: 1} = run()
    assert paid_count() == 0
  end

  test "a retry of a job that already uploaded goes straight to the bookkeeping", %{
    meditation: meditation,
    voice: voice
  } do
    enqueue(meditation, voice)
    [job] = all_enqueued(worker: NarrateMeditation)

    # As if an earlier attempt of this very job uploaded the clip and then
    # failed to write the narration row.
    FakeAwsHttpClient.put_object!(@key, %{
      "job" => to_string(job.id),
      "fingerprint" => fingerprint(meditation, voice)
    })

    assert %{success: 1} = run()
    assert paid_count() == 0
    assert [_narration] = Rosary.meditation_narrations(meditation)
  end

  # Job ids are only unique within one database: a production snapshot
  # restored into dev once carried production's ids along.
  test "an upload with this job's id but other words is not this job's", %{
    meditation: meditation,
    voice: voice
  } do
    enqueue(meditation, voice)
    [job] = all_enqueued(worker: NarrateMeditation)
    FakeAwsHttpClient.put_object!(@key, %{"job" => to_string(job.id), "fingerprint" => "other"})

    assert %{success: 1} = run()
    assert paid_count() == 1
  end

  # The lifeline frees a job killed by a deploy without recording an error,
  # so its next attempt has run ahead of its errors.
  test "an attempt killed mid-request is cancelled, not paid for again", %{
    meditation: meditation,
    voice: voice
  } do
    enqueue(meditation, voice)
    [job] = all_enqueued(worker: NarrateMeditation)
    orphaned = %{LumenViae.Repo.get!(Oban.Job, job.id) | attempt: 2, errors: []}

    assert {:cancel, reason} = NarrateMeditation.perform(orphaned)
    assert reason =~ "killed mid-request and may be billed"
    assert paid_count() == 0
  end

  test "a killed attempt whose own upload landed just finishes the bookkeeping", %{
    meditation: meditation,
    voice: voice
  } do
    enqueue(meditation, voice)
    [job] = all_enqueued(worker: NarrateMeditation)

    FakeAwsHttpClient.put_object!(@key, %{
      "job" => to_string(job.id),
      "fingerprint" => fingerprint(meditation, voice)
    })

    orphaned = %{LumenViae.Repo.get!(Oban.Job, job.id) | attempt: 2, errors: []}

    assert :ok = NarrateMeditation.perform(orphaned)
    assert paid_count() == 0
    assert [_narration] = Rosary.meditation_narrations(meditation)
  end

  test "an attempt after an ordinary failure is not taken for a killed one" do
    job = %Oban.Job{attempt: 2, errors: [%{"attempt" => 1, "error" => "429"}]}
    refute LumenViae.Audio.Recording.orphaned?(job)
    assert LumenViae.Audio.Recording.orphaned?(%{job | errors: []})
  end

  # Recordings made before fingerprints existed have no metadata at all.
  test "a legacy object is re-recorded by a plain regeneration, once", %{
    meditation: meditation,
    voice: voice
  } do
    FakeAwsHttpClient.put_object!(@key)

    enqueue(meditation, voice)
    run()
    assert paid_count() == 1

    # The new upload carries a fingerprint, so the same request again is free.
    enqueue(meditation, voice)
    run()
    assert paid_count() == 0
  end

  test "filling gaps (keep_existing) never pays to replace a legacy object", %{
    meditation: meditation,
    voice: voice
  } do
    FakeAwsHttpClient.put_object!(@key)

    enqueue(meditation, voice, keep_existing: true)
    assert %{success: 1} = run()
    assert paid_count() == 0

    # The object was there, so the gap filled is the missing narration row.
    assert [%{s3_key: @key}] = Rosary.meditation_narrations(meditation)
  end

  test "changed words are recorded again", %{meditation: meditation, voice: voice} do
    enqueue(meditation, voice)
    run()

    {:ok, _} =
      Rosary.update_meditation(meditation, %{content: "Entirely new words."}, actor: admin())

    enqueue(meditation, voice)
    run()
    assert paid_count() == 2
  end

  test "force records a second take, but a retry of that job still pays once", %{
    meditation: meditation,
    voice: voice
  } do
    enqueue(meditation, voice)
    run()

    enqueue(meditation, voice, force: true)
    [job] = all_enqueued(worker: NarrateMeditation)
    run()
    assert paid_count() == 2

    # The forced job retried after its upload: its own job id is on the
    # object, so it does not pay again.
    assert :ok = NarrateMeditation.perform(LumenViae.Repo.get!(Oban.Job, job.id))
    assert paid_count() == 0
  end

  test "audio that cannot be uploaded is not paid for again on a retry", %{
    meditation: meditation,
    voice: voice
  } do
    put_env([{:lumen_viae, :fake_aws_refuse_puts, true}])

    enqueue(meditation, voice)
    assert %{cancelled: 1} = run()
    assert paid_count() == 1

    [job] = Oban.Job |> LumenViae.Repo.all()
    assert hd(job.errors)["error"] =~ "not paid for twice"
  end

  test "a meditation deleted before its job runs cancels the job", %{
    meditation: meditation,
    voice: voice
  } do
    enqueue(meditation, voice)
    {:ok, _} = Rosary.delete_meditation(meditation, actor: admin())

    assert %{cancelled: 1} = run()
    assert paid_count() == 0
  end

  test "a finished job is broadcast on its batch", %{meditation: meditation, voice: voice} do
    AudioJobs.subscribe("watched-batch")
    enqueue(meditation, voice, batch: "watched-batch")
    run()

    assert_received {:audio_job,
                     %{batch: "watched-batch", key: @key, status: :recorded, message: message}}

    assert message =~ "recorded"
    assert %{total: 1, completed: 1, pending: 0, failed: 0} = AudioJobs.progress("watched-batch")
  end
end
