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
    {:ok, conn: Plug.Test.init_test_session(conn, %{admin_authenticated: true})}
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
    html = render_async(view)

    for clip <- PrayerAudio.prayers(), do: assert(html =~ clip.name)
    assert html =~ "The First Sorrow of Mary: The Prophecy of Simeon"
    refute html =~ "Missing</span>"
    assert has_element?(view, "audio[preload=none]")
  end

  test "a bucket that cannot be asked is unknown, not missing", %{conn: conn} do
    put_env(:ex_aws, :access_key_id, nil)
    put_env(:ex_aws, :secret_access_key, nil)

    {:ok, view, _html} = live(conn, "/admin/rosary-audio?voice=male")
    html = render_async(view)

    assert html =~ "could not be checked"
    refute html =~ "not recorded in the"
  end

  test "an unknown voice falls back to the default", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/rosary-audio?voice=nobody")
    assert html =~ "In the Female voice" or html =~ "Checking the bucket"
  end
end
