defmodule LumenViaeWeb.Live.Admin.MeditationsImportFlowTest do
  @moduledoc """
  The import screen's steps around the happy path `MeditationsImportTest`
  covers: the preview is a dry run that writes nothing, a file the importer
  cannot read is stopped before it, a row with an error is shown and left
  out, narration can be skipped, and the screen can be started over.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]
  import Phoenix.LiveViewTest

  alias LumenViae.Rosary
  alias LumenViae.Test.FakeAwsHttpClient

  @header "mystery_name,content,audio_filename,set_name,set_category\n"

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

  defp open(conn) do
    {:ok, view, _html} = live(conn, "/admin/meditations/import")
    view
  end

  defp upload_and_preview(view, csv) do
    view
    |> file_input("#import-form", :csv, [%{name: "batch.csv", content: csv, type: "text/csv"}])
    |> render_upload("batch.csv")

    view |> element("#import-form") |> render_submit()
  end

  defp meditation_contents do
    Rosary.list_meditations!(actor: admin()) |> Enum.map(& &1.content)
  end

  describe "the preview" do
    test "shows what would be imported and writes nothing", %{conn: conn} do
      view = open(conn)

      html =
        upload_and_preview(
          view,
          @header <>
            "The Annunciation,Behold the handmaid.,fiat.mp3,Preview Set,joyful\n" <>
            "The Annunciation,Hail full of grace.,,Preview Set,joyful\n"
        )

      assert html =~ "batch.csv"
      assert html =~ "Behold the handmaid."
      assert html =~ "Will create set(s): <strong>Preview Set</strong>"
      assert html =~ "fiat.mp3"
      assert html =~ "Start import"

      assert meditation_contents() == []
      assert Rosary.get_meditation_set_by_name("Preview Set", nil, actor: admin()) == nil
      assert %{success: 0} = Oban.drain_queue(queue: :elevenlabs)
    end

    test "asks for a file when none was chosen", %{conn: conn} do
      view = open(conn)

      html = view |> element("#import-form") |> render_submit()

      assert html =~ "Please choose a CSV file first"
      refute html =~ "Start import"
    end

    test "stops a file missing a required column before anything else",
         %{conn: conn} do
      view = open(conn)

      html = upload_and_preview(view, "content\nBehold the handmaid.\n")

      assert html =~ "CSV is missing required column(s): mystery_name"
      refute html =~ "Start import"
      assert meditation_contents() == []
    end

    test "marks a row whose mystery does not exist, and offers the valid rows only",
         %{conn: conn} do
      view = open(conn)

      html =
        upload_and_preview(
          view,
          @header <>
            "The Annunciation,Behold the handmaid.,,,\n" <>
            "The Nonexistent,An orphan passage.,,,\n"
        )

      assert html =~ "Error: mystery not found: The Nonexistent"
      assert html =~ "Import 1 valid row(s)"
      refute html =~ "Start import"
    end
  end

  describe "importing" do
    test "writes the valid rows and reports the one it could not", %{conn: conn} do
      view = open(conn)

      upload_and_preview(
        view,
        @header <>
          "The Annunciation,Behold the handmaid.,,,\n" <>
          "The Nonexistent,An orphan passage.,,,\n"
      )

      view |> element("button[phx-click=start-import]") |> render_click()
      render_async(view)
      html = render(view)

      assert html =~ "Import complete"
      assert html =~ "Mystery not found: The Nonexistent"
      assert meditation_contents() == ["Behold the handmaid."]
    end

    test "with narration skipped, writes the text and queues no recording",
         %{conn: conn} do
      view = open(conn)

      html =
        upload_and_preview(
          view,
          @header <> "The Annunciation,Behold the handmaid.,fiat.mp3,,\n"
        )

      assert html =~ "will be queued for recording"

      html = view |> element("input[phx-click=toggle-skip-audio]") |> render_click()
      assert html =~ "Skipped"
      refute html =~ "will be queued for recording"

      view |> element("button[phx-click=start-import]") |> render_click()
      render_async(view)

      assert render(view) =~ "Import complete"
      assert meditation_contents() == ["Behold the handmaid."]
      assert %{success: 0, failure: 0} = Oban.drain_queue(queue: :elevenlabs)
    end
  end

  describe "starting over" do
    test "Cancel on the preview returns to the upload and writes nothing", %{conn: conn} do
      view = open(conn)
      upload_and_preview(view, @header <> "The Annunciation,Behold the handmaid.,,,\n")

      html = view |> element("button[phx-click=reset]", "Cancel") |> render_click()

      assert has_element?(view, "#import-form")
      refute html =~ "Behold the handmaid."
      assert meditation_contents() == []
    end

    test "Import another file returns to the upload after an import", %{conn: conn} do
      view = open(conn)
      upload_and_preview(view, @header <> "The Annunciation,Behold the handmaid.,,,\n")
      view |> element("button[phx-click=start-import]") |> render_click()
      render_async(view)

      view |> element("button", "Import another file") |> render_click()

      assert has_element?(view, "#import-form")
      refute render(view) =~ "Import complete"
    end

    test "a stray start-import before any preview does nothing", %{conn: conn} do
      view = open(conn)

      render_click(view, "start-import", %{})

      assert has_element?(view, "#import-form")
      assert meditation_contents() == []
    end
  end
end
