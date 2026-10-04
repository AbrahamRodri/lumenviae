defmodule LumenViaeWeb.Live.Meditations.NarrationPanelTest do
  @moduledoc """
  The Narration panel on the meditation edit page: each voice's recording,
  and recording one from the console. Oban runs in manual mode here, so a
  recording is queued and never sent to ElevenLabs.
  """
  use LumenViaeWeb.ConnCase, async: true
  use Oban.Testing, repo: LumenViae.Repo

  import Phoenix.LiveViewTest

  alias LumenViae.Curation.Jobs.NarrateMeditation
  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "The Annunciation",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    {:ok, conn: log_in_admin(conn), mystery: mystery}
  end

  defp create_meditation(mystery, attrs) do
    defaults = %{content: "The angel came in unto her.", mystery_id: mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs), actor: admin())
    meditation
  end

  test "a voice with no recording is recorded with one press", %{conn: conn, mystery: mystery} do
    meditation = create_meditation(mystery, %{audio_url: "Joyful-Test-1.mp3"})
    {:ok, view, html} = live(conn, "/admin/meditations/#{meditation.id}/edit")

    assert html =~ "Not recorded"

    html =
      view
      |> element("button[phx-click=record_narration][phx-value-voice=female]")
      |> render_click()

    assert html =~ "Queued"

    assert_enqueued(
      worker: NarrateMeditation,
      args: %{meditation_id: meditation.id, voice: "female", force: false}
    )
  end

  test "a meditation with no audio filename cannot be recorded", %{conn: conn, mystery: mystery} do
    meditation = create_meditation(mystery, %{})
    {:ok, view, html} = live(conn, "/admin/meditations/#{meditation.id}/edit")

    assert html =~ "No audio filename"
    refute has_element?(view, "button[phx-click=record_narration]")
  end

  test "a recorded voice is recorded again only on purpose, as a paid second take", %{
    conn: conn,
    mystery: mystery
  } do
    meditation = create_meditation(mystery, %{audio_url: "Joyful-Test-2.mp3"})

    {:ok, _} =
      Rosary.record_narration(meditation, "female", "voices/female/Joyful-Test-2.mp3",
        actor: admin()
      )

    {:ok, view, html} = live(conn, "/admin/meditations/#{meditation.id}/edit")
    assert html =~ "Recorded"

    view
    |> element("button[phx-click=record_narration][phx-value-voice=female][phx-value-force]")
    |> render_click()

    assert_enqueued(worker: NarrateMeditation, args: %{voice: "female", force: true})
  end
end
