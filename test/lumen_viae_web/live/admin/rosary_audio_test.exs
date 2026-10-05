defmodule LumenViaeWeb.Live.Admin.RosaryAudioTest do
  @moduledoc """
  The spoken Rosary screen: every clip listed with a player, its coverage
  checked after the page is up, and a bucket that cannot be asked reported
  as unknown rather than as missing.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]
  import Phoenix.LiveViewTest

  alias LumenViae.Rosary.PrayerAudio

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  defp with_bucket do
    # The fake S3 client answers every HEAD 200, so every clip is recorded.
    put_env(:ex_aws, :http_client, LumenViae.Test.FakeAwsHttpClient)
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")
    put_env(:lumen_viae, :fake_aws_test_pid, self())
  end

  test "lists every clip, and shows them recorded once the bucket answers", %{conn: conn} do
    with_bucket()
    {:ok, view, html} = live(conn, "/admin/rosary-audio")

    assert html =~ "Checking"
    html = render_async(view, 10_000)

    for clip <- PrayerAudio.prayers(), do: assert(html =~ clip.name)
    assert html =~ "The First Sorrow of Mary: The Prophecy of Simeon"
    refute html =~ "Missing</span>"
    assert has_element?(view, "audio[preload=none]")
  end

  test "a bucket that cannot be asked is unknown, not missing", %{conn: conn} do
    put_env(:ex_aws, :access_key_id, nil)
    put_env(:ex_aws, :secret_access_key, nil)

    {:ok, view, _html} = live(conn, "/admin/rosary-audio?voice=male")
    html = render_async(view, 10_000)

    assert html =~ "could not be checked"
    refute html =~ "not recorded in the"
  end

  test "follows a recording run live: Recording while queued, Recorded when it lands", %{
    conn: conn
  } do
    with_bucket()
    LumenViae.Test.FakeAwsHttpClient.store!()

    clip = Enum.find(PrayerAudio.prayers(), &(&1.name == "sign_of_cross"))
    voice = LumenViae.Rosary.Voices.default()

    {:ok, :queued} =
      clip
      |> LumenViae.Curation.Jobs.RecordRosaryClip.new_for(voice)
      |> LumenViae.Curation.AudioJobs.enqueue("live-run")

    {:ok, view, _html} = live(conn, "/admin/rosary-audio")
    html = render_async(view, 10_000)

    # The job was waiting when the page connected.
    assert html =~ "1 clip(s) are being recorded now"
    assert html =~ ~r/>\s*Recording\s*<\/span>/

    put_env(:lumen_viae, :eleven_labs_api_key, "test-api-key")
    put_env(:lumen_viae, :eleven_labs_req_options, plug: {Req.Test, LumenViae.Audio.ElevenLabs})
    Req.Test.stub(LumenViae.Audio.ElevenLabs, &Plug.Conn.send_resp(&1, 200, "audio-bytes"))

    assert %{success: 1} = Oban.drain_queue(queue: :elevenlabs)

    html = render(view)
    refute html =~ "being recorded now"
    refute html =~ ~r/>\s*Recording\s*<\/span>/
  end

  test "an unknown voice falls back to the default", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/rosary-audio?voice=nobody")
    assert html =~ "In the Female voice" or html =~ "Checking the bucket"
  end
end
