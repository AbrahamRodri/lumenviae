defmodule LumenViaeWeb.Live.Pray.NavigationTest do
  @moduledoc """
  Moving through a set on `/meditation-sets/:id/pray`: Next and Previous,
  the beads, the arrow keys, and the mobile view. The mystery and the view
  ride in the URL, so a reload or a shared link lands where the reader was.
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
          description: "The mystery's own description."
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

  defp at(path, mystery, mobile \\ false), do: "#{path}?mystery=#{mystery}&mobile=#{mobile}"

  describe "Next and Previous" do
    test "step through the set, each step a patch of the URL", %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, path)
      assert html =~ "Passage 1."
      assert html =~ "Mystery I of V"

      view |> element("button[phx-click=next]") |> render_click()
      assert_patch(view, at(path, 1))
      assert render(view) =~ "Passage 2."
      assert render(view) =~ "Mystery II of V"

      view |> element("button[phx-click=previous]") |> render_click()
      assert_patch(view, at(path, 0))
      assert render(view) =~ "Passage 1."
    end

    test "Previous is disabled on the first mystery", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      assert has_element?(view, "button[phx-click=previous][disabled]")

      view |> element("button[phx-click=next]") |> render_click()
      refute has_element?(view, "button[phx-click=previous][disabled]")
    end

    test "the last mystery offers Complete instead of Next", %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, at(path, 4))

      assert html =~ "Passage 5."
      assert html =~ "Mystery V of V"
      assert has_element?(view, "button[phx-click=complete]")
      refute has_element?(view, "button[phx-click=next]")
    end
  end

  describe "the mystery in the URL" do
    test "opens the set at that mystery", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, "#{path}?mystery=2")

      assert html =~ "Passage 3."
    end

    test "past the end lands on the last mystery", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, "#{path}?mystery=99")

      assert html =~ "Passage 5."
    end

    test "below zero or unreadable lands on the first", %{conn: conn, path: path} do
      for mystery <- ["-3", "abc"] do
        {:ok, _view, html} = live(conn, "#{path}?mystery=#{mystery}")

        assert html =~ "Passage 1.", "?mystery=#{mystery}"
      end
    end
  end

  describe "the beads" do
    test "jump to a mystery and mark it as the current step", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      view |> element("button[phx-click=go_to][phx-value-index='3']") |> render_click()

      assert_patch(view, at(path, 3))
      assert render(view) =~ "Passage 4."
      assert has_element?(view, ~s(button[phx-value-index='3'][aria-current="step"]))
      assert has_element?(view, ~s(button[phx-value-index='0'][aria-current="false"]))
    end
  end

  describe "the arrow keys" do
    test "right goes forward and left goes back", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      render_keydown(view, "key_nav", %{"key" => "ArrowRight"})
      assert_patch(view, at(path, 1))

      render_keydown(view, "key_nav", %{"key" => "ArrowLeft"})
      assert_patch(view, at(path, 0))
    end

    # The last mystery ends with a deliberate press of Complete; a key that
    # walked past it would be no way to finish a Rosary.
    test "right does nothing on the last mystery", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, 4))

      render_keydown(view, "key_nav", %{"key" => "ArrowRight"})

      refute_patched(view)
      assert render(view) =~ "Passage 5."
    end

    test "left does nothing on the first, and other keys do nothing at all",
         %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, 0))

      render_keydown(view, "key_nav", %{"key" => "ArrowLeft"})
      assert_patch(view, at(path, 0))
      assert render(view) =~ "Passage 1."

      render_keydown(view, "key_nav", %{"key" => "Enter"})
      refute_patched(view)
    end
  end

  describe "the mobile view" do
    test "the switch turns it on and off, keeping the reader's place",
         %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, at(path, 2))
      assert html =~ "The mystery&#39;s own description."

      view |> element("button[phx-click=toggle_mobile_mode]") |> render_click()
      assert_patch(view, at(path, 2, true))

      # The mobile view is for listening: the place is kept, the page's
      # reading furniture is put away.
      html = render(view)
      assert html =~ "Mystery III of V"
      assert html =~ "Switch to full view"
      refute html =~ "Passage 3."
      refute html =~ "The mystery&#39;s own description."

      view |> element("button[phx-click=toggle_mobile_mode]") |> render_click()
      assert_patch(view, at(path, 2, false))
      assert render(view) =~ "Switch to mobile view"
    end

    test "the MobileMode hook can turn it on for a small screen", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      view
      |> element("[phx-hook=MobileMode]")
      |> render_hook("init_mobile_mode", %{"enabled" => true})

      assert_patch(view, at(path, 0, true))
      assert render(view) =~ "Switch to full view"
    end

    test "survives moving to the next mystery", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, at(path, 0, true))

      view |> element("button[phx-click=next]") |> render_click()

      assert_patch(view, at(path, 1, true))
    end
  end

  test "the end of a narration moves nothing on its own", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)

    render_hook(view, "audio_ended", %{})

    refute_patched(view)
    assert render(view) =~ "Passage 1."
  end
end
