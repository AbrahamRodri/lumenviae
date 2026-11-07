defmodule LumenViaeWeb.Live.Pray.NavigationTest do
  @moduledoc """
  Moving through a Rosary on `/meditation-sets/:id/pray`, a bead at a time:
  the opening prayers, each decade, the closing prayers. Next and Previous,
  the strand's decades, the arrow keys. The place rides in the URL, so a
  reload or a shared link lands where the reader was. A step past the end
  of a page is held to its last bead, which is how these tests reach one.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Navigation Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive]),
          description: "The mystery's own description.",
          fruit: "Humility"
        },
        actor: admin()
      )

    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Navigation Set #{System.unique_integer([:positive])}", category: "joyful"},
        actor: admin()
      )

    for order <- 1..5 do
      {:ok, meditation} =
        Rosary.create_meditation(%{content: "Passage #{order}.", mystery_id: mystery.id},
          actor: admin()
        )

      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order, actor: admin())
    end

    %{set: set, path: "/meditation-sets/#{set.id}/pray"}
  end

  defp at(path, mystery, step \\ 0), do: "#{path}?mystery=#{mystery}&step=#{step}"

  describe "the whole Rosary" do
    test "the Crucifixion stands above the closing prayers; no painting, no space",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, "closing"))
      assert view |> element(".prayer-hero img") |> render() =~ "sorrowful_crucifixion"

      # This set's test mysteries have no painting, so the opening keeps none.
      {:ok, view, _html} = live(conn, path)
      refute has_element?(view, ".prayer-hero")
    end

    test "opens on the Sign of the Cross, in the app's words", %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, path)

      assert html =~ "In the name of the Father"
      assert view |> element("#bead-status") |> render() =~ "The Sign of the Cross"
      refute html =~ "The Apostles&#39; Creed"
      refute html =~ "Passage 1."
    end

    test "the opening prayers follow, a bead each", %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, at(path, "opening", 1))

      assert html =~ "The Apostles&#39; Creed"
      assert html =~ "I believe in God, the Father almighty"

      view |> element("button[phx-click=next]") |> render_click()
      assert render(view) =~ "The Our Father"
    end

    test "a decade opens on its announcement and its fruit, then its meditation",
         %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, at(path, 0))

      assert html =~ "The First Joyful Mystery"
      assert html =~ "Ask for"
      assert html =~ "Humility"
      refute html =~ "Passage 1."

      view |> element("button[phx-click=next]") |> render_click()
      assert render(view) =~ "Passage 1."
      assert view |> element("#bead-status") |> render() =~ "The meditation"
    end

    test "a decade's last two beads are the Glory Be and the Fatima Prayer",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, 0, 999))

      assert view |> element("#bead-status") |> render() =~ "The Fatima Prayer"

      render_keydown(view, "key_nav", %{"key" => "ArrowLeft"})
      assert view |> element("#bead-status") |> render() =~ "The Glory Be"
    end

    test "the title block names the part, where it falls and the step",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, 0, 999))
      title = view |> element("#bead-title") |> render()
      assert title =~ "Mystery 1 of 5"

      # The announcement shows the same name and place, so the page does not
      # move between a mystery's steps, and its card does not repeat it.
      {:ok, announced, _html} = live(conn, at(path, 0))
      announced_title = announced |> element("#bead-title") |> render()
      [_, name] = Regex.run(~r/<p aria-hidden="true"[^>]*>\s*([^<]+?)\s*</, announced_title)
      assert title =~ name
      assert announced_title =~ "Mystery 1 of 5"
      refute announced |> element("[data-screen]") |> render() =~ "<h2"

      {:ok, opening, _html} = live(conn, path)
      opening_title = opening |> element("#bead-title") |> render()
      assert opening_title =~ "The Opening Prayers"
      assert opening_title =~ "Before the first mystery"

      {:ok, closing, _html} = live(conn, at(path, "closing"))
      assert closing |> element("#bead-title") |> render() =~ "After the last mystery"
    end

    test "the closing prayers begin with Hail, Holy Queen and end with Complete",
         %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, at(path, "closing"))

      assert html =~ "Hail, Holy Queen"
      refute has_element?(view, "button[phx-click=complete]")
      assert has_element?(view, "button[phx-click=next]")

      {:ok, view, _html} = live(conn, at(path, "closing", 999))

      assert view |> element("#bead-status") |> render() =~ "The Sign of the Cross"
      assert has_element?(view, "button[phx-click=complete]")
      refute has_element?(view, "button[phx-click=next]")
    end
  end

  describe "Next and Previous" do
    test "step through the Rosary a bead at a time, each step a patch of the URL",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)
      assert has_element?(view, "button[phx-click=previous][disabled]")

      view |> element("button[phx-click=next]") |> render_click()
      assert_patch(view, at(path, "opening", 1))
      assert render(view) =~ "The Apostles&#39; Creed"

      view |> element("button[phx-click=previous]") |> render_click()
      assert_patch(view, at(path, "opening", 0))
    end

    test "Next from the last opening prayer opens the first decade, and Back returns",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, "opening", 999))
      refute has_element?(view, "button[phx-click=previous][disabled]")

      view |> element("button[phx-click=next]") |> render_click()
      assert_patch(view, at(path, 0, 0))
      assert render(view) =~ "The First Joyful Mystery"

      view |> element("button[phx-click=next]") |> render_click()
      assert_patch(view, at(path, 0, 1))
      assert render(view) =~ "Passage 1."

      view |> element("button[phx-click=previous]") |> render_click()
      assert_patch(view, at(path, 0, 0))

      view |> element("button[phx-click=previous]") |> render_click()
      assert assert_patch(view) =~ "mystery=opening"
    end

    test "Next from the last decade goes to the closing prayers", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, 4, 999))

      refute has_element?(view, "button[phx-click=complete]")

      view |> element("button[phx-click=next]") |> render_click()
      assert_patch(view, at(path, "closing", 0))
      refute has_element?(view, "button[phx-click=complete]")
    end
  end

  describe "the mystery in the URL" do
    test "opens the Rosary at that decade's first bead", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, at(path, 2))

      assert html =~ "The Third Joyful Mystery"
      refute html =~ "Passage 3."
    end

    test "past the end lands on the last decade", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, at(path, 99))

      assert html =~ "The Fifth Joyful Mystery"
    end

    test "below zero is the first decade, and unreadable the beginning",
         %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, at(path, "-3"))
      assert html =~ "The First Joyful Mystery"

      {:ok, _view, html} = live(conn, at(path, "abc"))
      assert html =~ "In the name of the Father"
    end

    test "old links still open, their counting, aloud and mobile choices ignored",
         %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, "#{path}?mystery=2&mobile=true&count=beads&aloud=false")

      assert html =~ "The Third Joyful Mystery"
      refute has_element?(view, "button[phx-click=toggle_mobile_mode]")

      # The next URL is the new one: no trace of the old choices.
      view |> element("button[phx-click=next]") |> render_click()
      assert_patch(view, at(path, 2, 1))
    end
  end

  describe "the Go to list" do
    test "jumps to a decade and closes", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      view |> element("#go-to-toggle") |> render_click()
      view |> element("#prayer-go-to button[phx-value-page='4']") |> render_click()

      assert_patch(view, at(path, 3, 0))
      assert render(view) =~ "The Fourth Joyful Mystery"
      refute has_element?(view, "#prayer-go-to")
      assert has_element?(view, "#go-to-toggle", "Mystery 4 of 5")
    end
  end

  describe "the arrow keys" do
    test "right goes forward a bead and left goes back", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, 0))

      render_keydown(view, "key_nav", %{"key" => "ArrowRight"})
      assert_patch(view, at(path, 0, 1))

      render_keydown(view, "key_nav", %{"key" => "ArrowLeft"})
      assert_patch(view, at(path, 0, 0))
    end

    test "space, enter and the down arrow go forward, the up arrow back",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      for {key, step} <- [{" ", 1}, {"Enter", 2}, {"ArrowDown", 3}] do
        render_keydown(view, "key_nav", %{"key" => key})
        assert_patch(view, at(path, "opening", step))
      end

      render_keydown(view, "key_nav", %{"key" => "ArrowUp"})
      assert_patch(view, at(path, "opening", 2))
    end

    # The Rosary ends with a deliberate press of Complete; a key that
    # walked past it would be no way to finish one.
    test "right does nothing on the last bead of the closing prayers",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, "closing", 999))

      render_keydown(view, "key_nav", %{"key" => "ArrowRight"})

      refute_patched(view)
    end

    test "left does nothing at the beginning, and other keys do nothing at all",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      render_keydown(view, "key_nav", %{"key" => "ArrowLeft"})
      refute_patched(view)

      for key <- ["a", "Tab", "Escape"] do
        render_keydown(view, "key_nav", %{"key" => key})
        refute_patched(view)
      end
    end
  end

  test "the end of a narration moves nothing on its own", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, at(path, 0))

    render_hook(view, "audio_ended", %{})

    refute_patched(view)
    assert render(view) =~ "The First Joyful Mystery"
  end
end
