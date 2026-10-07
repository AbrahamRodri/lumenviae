defmodule LumenViaeWeb.Live.Pray.NavigationTest do
  @moduledoc """
  Moving through a Rosary on `/meditation-sets/:id/pray`, counting on your
  own rosary: the opening prayers, a page per decade, the closing prayers.
  Next and Previous, the strand's beads, the arrow keys. The place rides
  in the URL, so a reload or a shared link lands where the reader was.
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

  defp at(path, mystery), do: "#{path}?mystery=#{mystery}"

  describe "the whole Rosary" do
    test "opens on the opening prayers, in the app's words", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, path)

      assert html =~ "The Opening Prayers"
      assert html =~ "The Apostles&#39; Creed"
      assert html =~ "I believe in God, the Father almighty"
      assert html =~ "A Hail Mary for faith · A Hail Mary for hope · A Hail Mary for charity"
      refute html =~ "Passage 1."
    end

    test "a decade is its announcement, its fruit and its meditation", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, at(path, 0))

      assert html =~ "The First Joyful Mystery"
      assert html =~ "Ask for"
      assert html =~ "Humility"
      assert html =~ "Passage 1."
      assert html =~ "Mystery I of V"
      assert html =~ "Ten Hail Marys"
      assert html =~ "The Glory Be and the Fatima Prayer"
    end

    test "the closing prayers end with Complete", %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, at(path, "closing"))

      assert html =~ "The Closing Prayers"
      assert html =~ "Hail, Holy Queen"
      assert has_element?(view, "button[phx-click=complete]")
      refute has_element?(view, "button[phx-click=next]")
    end
  end

  describe "Next and Previous" do
    test "step through the Rosary, each step a patch of the URL", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)
      assert has_element?(view, "button[phx-click=previous][disabled]")

      view |> element("button[phx-click=next]") |> render_click()
      assert_patch(view, at(path, 0))
      assert render(view) =~ "Passage 1."

      view |> element("button[phx-click=next]") |> render_click()
      assert_patch(view, at(path, 1))
      assert render(view) =~ "Passage 2."
      assert render(view) =~ "Mystery II of V"

      view |> element("button[phx-click=previous]") |> render_click()
      assert_patch(view, at(path, 0))

      view |> element("button[phx-click=previous]") |> render_click()
      assert_patch(view, at(path, "opening"))
    end

    test "Next from the last decade goes to the closing prayers", %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, at(path, 4))

      assert html =~ "Passage 5."
      refute has_element?(view, "button[phx-click=complete]")

      view |> element("button[phx-click=next]") |> render_click()
      assert_patch(view, at(path, "closing"))
      assert has_element?(view, "button[phx-click=complete]")
    end
  end

  describe "the mystery in the URL" do
    test "opens the Rosary at that decade", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, at(path, 2))

      assert html =~ "Passage 3."
    end

    test "past the end lands on the last decade", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, at(path, 99))

      assert html =~ "Passage 5."
    end

    test "below zero is the first decade, and unreadable the beginning",
         %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, at(path, "-3"))
      assert html =~ "Passage 1."

      {:ok, _view, html} = live(conn, at(path, "abc"))
      assert html =~ "The Opening Prayers"
    end

    test "old links still open, their mobile switch ignored", %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, "#{path}?mystery=2&mobile=true")

      assert html =~ "Passage 3."
      refute has_element?(view, "button[phx-click=toggle_mobile_mode]")
    end
  end

  describe "the strand" do
    test "jumps to a part of the Rosary and marks it as the current step",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      view |> element("button[phx-click=go_to][phx-value-page='4']") |> render_click()

      assert_patch(view, at(path, 3))
      assert render(view) =~ "Passage 4."
      assert has_element?(view, ~s(button[phx-value-page='4'][aria-current="step"]))
      assert has_element?(view, ~s(button[phx-value-page='0'][aria-current="false"]))
    end
  end

  describe "the arrow keys" do
    test "right goes forward and left goes back", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, 0))

      render_keydown(view, "key_nav", %{"key" => "ArrowRight"})
      assert_patch(view, at(path, 1))

      render_keydown(view, "key_nav", %{"key" => "ArrowLeft"})
      assert_patch(view, at(path, 0))
    end

    # The Rosary ends with a deliberate press of Complete; a key that
    # walked past it would be no way to finish one.
    test "right does nothing on the closing prayers", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, "closing"))

      render_keydown(view, "key_nav", %{"key" => "ArrowRight"})

      refute_patched(view)
    end

    # Counting on a rosary, Space and the up and down arrows scroll a long
    # meditation rather than turning the page.
    test "left does nothing at the beginning, and other keys do nothing at all",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      render_keydown(view, "key_nav", %{"key" => "ArrowLeft"})
      refute_patched(view)

      for key <- ["Enter", " ", "ArrowDown"] do
        render_keydown(view, "key_nav", %{"key" => key})
        refute_patched(view)
      end
    end
  end

  test "the end of a narration moves nothing on its own", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, at(path, 0))

    render_hook(view, "audio_ended", %{})

    refute_patched(view)
    assert render(view) =~ "Passage 1."
  end
end
