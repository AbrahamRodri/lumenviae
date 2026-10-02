defmodule LumenViaeWeb.Live.Meditations.FormTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, mystery} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1},
        actor: admin()
      )

    {:ok, conn: log_in_admin(conn), mystery: mystery}
  end

  defp create_meditation(mystery, attrs \\ %{}) do
    defaults = %{content: "The angel came in unto her.", mystery_id: mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs), actor: admin())
    meditation
  end

  describe "new" do
    test "creates a meditation with its paragraph breaks intact", %{conn: conn, mystery: mystery} do
      {:ok, view, _html} = live(conn, "/admin/meditations/new")
      content = "First paragraph.\n\nSecond paragraph."

      view
      |> form("form[phx-submit=create_meditation]", %{
        meditation: %{
          mystery_id: mystery.id,
          title: "On the Annunciation",
          content: content,
          author: "St. Alphonsus Liguori",
          audio_url: "Joyful-Liguori-1.mp3"
        }
      })
      |> render_submit()

      assert [meditation] = Rosary.list_meditations!(actor: admin())
      assert meditation.content == content
      assert meditation.title == "On the Annunciation"
      assert meditation.audio_url == "Joyful-Liguori-1.mp3"
      assert meditation.mystery_id == mystery.id

      assert_redirect(view, "/admin/meditations/#{meditation.id}/edit")
    end

    test "keeps what was typed and shows why it was refused", %{conn: conn, mystery: mystery} do
      {:ok, view, _html} = live(conn, "/admin/meditations/new")

      html =
        view
        |> form("form[phx-submit=create_meditation]", %{
          meditation: %{
            mystery_id: mystery.id,
            author: "A careful curator",
            content: "A pause {pause:2} left in by mistake."
          }
        })
        |> render_submit()

      assert html =~ "Failed to create meditation"
      assert html =~ "contains an unprocessed {pause:N} marker"
      assert html =~ ~s(value="A careful curator")
      assert html =~ "A pause {pause:2} left in by mistake."
      assert Rosary.list_meditations!(actor: admin()) == []
    end
  end

  describe "edit" do
    test "shows the stored text and saves an edit", %{conn: conn, mystery: mystery} do
      meditation = create_meditation(mystery, %{author: "Fulton Sheen"})
      {:ok, view, html} = live(conn, "/admin/meditations/#{meditation.id}/edit")

      assert html =~ "The angel came in unto her."
      assert html =~ ~s(value="Fulton Sheen")

      html =
        view
        |> form("form[phx-submit=update_meditation]", %{
          meditation: %{author: "Venerable Fulton J. Sheen"}
        })
        |> render_submit()

      assert html =~ "Meditation updated successfully"

      assert Rosary.get_meditation!(meditation.id, actor: admin()).author ==
               "Venerable Fulton J. Sheen"
    end

    test "an edit to the words clears the narration pauses that indexed them", %{
      conn: conn,
      mystery: mystery
    } do
      meditation =
        create_meditation(mystery, %{tts_annotations: [%{"offset" => 5, "seconds" => 2.0}]})

      {:ok, view, _html} = live(conn, "/admin/meditations/#{meditation.id}/edit")

      view
      |> form("form[phx-submit=update_meditation]", %{
        meditation: %{content: "The angel Gabriel came in unto her."}
      })
      |> render_submit()

      saved = Rosary.get_meditation!(meditation.id, actor: admin())
      assert saved.content == "The angel Gabriel came in unto her."
      assert saved.tts_annotations == []
    end

    test "refuses narration markup and leaves the meditation as it was", %{
      conn: conn,
      mystery: mystery
    } do
      meditation = create_meditation(mystery)
      {:ok, view, _html} = live(conn, "/admin/meditations/#{meditation.id}/edit")

      html =
        view
        |> form("form[phx-submit=update_meditation]", %{
          meditation: %{content: ~s(A pause <break time="1s" /> here.)}
        })
        |> render_submit()

      assert html =~ "Failed to update meditation"
      assert html =~ "must not contain &lt;break&gt; tags"

      assert Rosary.get_meditation!(meditation.id, actor: admin()).content ==
               "The angel came in unto her."
    end

    test "two saves in a row both land", %{conn: conn, mystery: mystery} do
      meditation = create_meditation(mystery)
      {:ok, view, _html} = live(conn, "/admin/meditations/#{meditation.id}/edit")

      for title <- ["First title", "Second title"] do
        view
        |> form("form[phx-submit=update_meditation]", %{meditation: %{title: title}})
        |> render_submit()
      end

      assert Rosary.get_meditation!(meditation.id, actor: admin()).title == "Second title"
    end

    test "a meditation that does not exist is a 404", %{conn: conn} do
      error = assert_raise Ash.Error.Invalid, fn -> live(conn, "/admin/meditations/0/edit") end

      assert Plug.Exception.status(error) == 404
    end
  end
end
