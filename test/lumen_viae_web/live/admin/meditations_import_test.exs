defmodule LumenViaeWeb.Live.Admin.MeditationsImportTest do
  @moduledoc """
  The import screen writes the rows, then follows the narration jobs it
  enqueued as they land, over PubSub.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]
  import Phoenix.LiveViewTest

  alias LumenViae.Rosary
  alias LumenViae.Test.FakeAwsHttpClient

  setup %{conn: conn} do
    put_env([
      {:lumen_viae, :eleven_labs_api_key, "test-api-key"},
      {:lumen_viae, :eleven_labs_req_options, plug: {Req.Test, LumenViae.Audio.ElevenLabs}},
      {:ex_aws, :http_client, FakeAwsHttpClient},
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    FakeAwsHttpClient.store!()

    Req.Test.stub(LumenViae.Audio.ElevenLabs, fn conn ->
      Plug.Conn.send_resp(conn, 200, "audio-bytes")
    end)

    {:ok, _} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1},
        actor: admin()
      )

    {:ok, conn: log_in_admin(conn)}
  end

  test "imports the rows, then shows each narration as it is recorded", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/meditations/import")

    csv = "mystery_name,content,audio_filename\nThe Annunciation,Behold the handmaid.,fiat.mp3\n"

    view
    |> file_input("#import-form", :csv, [%{name: "fiat.csv", content: csv, type: "text/csv"}])
    |> render_upload("fiat.csv")

    view |> element("#import-form") |> render_submit()
    view |> element("button", "Start import") |> render_click()
    render_async(view)

    html = render(view)
    assert html =~ "Import complete"
    assert html =~ "Narration"
    assert html =~ "voices/female/fiat.mp3"
    assert html =~ "Queued"

    # The jobs run here, in the test's process; their broadcasts reach the
    # page as they would from either production machine.
    assert %{success: 2} = Oban.drain_queue(queue: :elevenlabs)

    html = render(view)
    assert html =~ "2 recorded, 0 failed, 0 waiting, of 2"
    refute html =~ ">Queued<"
  end
end
