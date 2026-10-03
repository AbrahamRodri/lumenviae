defmodule LumenViae.Curation.Jobs.RecordRosaryClipTest do
  use LumenViae.DataCase, async: false
  use Oban.Testing, repo: LumenViae.Repo

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Curation.AudioJobs
  alias LumenViae.Curation.Jobs.RecordRosaryClip
  alias LumenViae.Rosary.{PrayerAudio, Voices}
  alias LumenViae.Test.FakeAwsHttpClient

  setup do
    test_pid = self()

    put_env([
      {:lumen_viae, :eleven_labs_api_key, "test-api-key"},
      {:lumen_viae, :eleven_labs_req_options, plug: {Req.Test, LumenViae.Audio.ElevenLabs}},
      {:ex_aws, :http_client, FakeAwsHttpClient},
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    FakeAwsHttpClient.store!()

    Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
      send(test_pid, :paid)
      Plug.Conn.send_resp(conn, 200, "audio-bytes")
    end)

    clip = Enum.find(PrayerAudio.prayers(), &(&1.name == "sign_of_cross"))
    %{clip: clip, voice: Voices.get("female")}
  end

  test "records a missing clip once", %{clip: clip, voice: voice} do
    clip |> RecordRosaryClip.new_for(voice) |> AudioJobs.enqueue("b")
    assert %{success: 1} = Oban.drain_queue(queue: :elevenlabs)
    assert_received :paid

    clip |> RecordRosaryClip.new_for(voice) |> AudioJobs.enqueue("b")
    assert %{success: 1} = Oban.drain_queue(queue: :elevenlabs)
    refute_received :paid
  end

  # A spoken Rosary key carries the hash of its words, so whatever is there
  # is right, even an object recorded before fingerprints existed.
  test "any object already at the key counts as recorded", %{clip: clip, voice: voice} do
    FakeAwsHttpClient.put_object!(PrayerAudio.s3_key(voice, clip))

    clip |> RecordRosaryClip.new_for(voice) |> AudioJobs.enqueue("b")
    assert %{success: 1} = Oban.drain_queue(queue: :elevenlabs)
    refute_received :paid
  end

  test "a clip reworded after it was queued is cancelled, not recorded", %{
    clip: clip,
    voice: voice
  } do
    changeset = RecordRosaryClip.new_for(clip, voice)
    args = Ecto.Changeset.get_field(changeset, :args)
    stale = Ecto.Changeset.put_change(changeset, :args, %{args | key: args.key <> "-old"})
    AudioJobs.enqueue(stale, "b")

    assert %{cancelled: 1} = Oban.drain_queue(queue: :elevenlabs)
    refute_received :paid
  end
end
