defmodule LumenViaeWeb.Live.Pray.GoToTest do
  @moduledoc """
  The pill at the top of the prayer page that names where the reader is,
  the Go to list it opens, and the "Show Words and Beads" switch in the
  settings pane.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Go To Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive]),
          description: "The mystery's own description.",
          fruit: "Humility"
        },
        actor: admin()
      )

    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Go To Set #{System.unique_integer([:positive])}", category: "joyful"},
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

  defp pill(view), do: view |> element("#go-to-toggle") |> render()

  describe "the pill" do
    test "names the part the reader is in", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)
      assert pill(view) =~ "Opening Prayers"

      {:ok, view, _html} = live(conn, path <> "?mystery=2")
      assert pill(view) =~ "Mystery 3 of 5"

      {:ok, view, _html} = live(conn, path <> "?mystery=closing")
      assert pill(view) =~ "Closing Prayers"
    end

    test "counts the Seven Sorrows out of seven", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/seven_sorrows/pray?mystery=1")
      assert pill(view) =~ "Mystery 2 of 7"
    end

    test "has a dot a part, the current one gilt", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path <> "?mystery=1")

      assert view |> element("#go-to-toggle + ol") |> render() |> String.split("<li") |> length() ==
               8

      assert view
             |> element("#go-to-toggle + ol")
             |> render()
             |> String.split("bg-gilt")
             |> length() == 2
    end
  end

  describe "the Go to list" do
    test "opens with every part, Here on the current one", %{conn: conn, path: path, set: set} do
      {:ok, view, _html} = live(conn, path <> "?mystery=1")

      refute has_element?(view, "#prayer-go-to")

      assert has_element?(
               view,
               ~s(#go-to-toggle[aria-expanded="false"][aria-controls="prayer-go-to"])
             )

      view |> element("#go-to-toggle") |> render_click()

      assert has_element?(view, ~s(#go-to-toggle[aria-expanded="true"]))
      assert has_element?(view, "#prayer-go-to", "Go to")
      assert has_element?(view, "#prayer-go-to", set.name)
      assert has_element?(view, "#prayer-go-to button[phx-click=go_to]", "The Opening Prayers")
      assert has_element?(view, "#prayer-go-to button[phx-click=go_to]", "The Closing Prayers")

      for n <- 1..5 do
        assert has_element?(view, "#prayer-go-to button", "Mystery #{n} of 5")
      end

      assert has_element?(
               view,
               "#prayer-go-to button",
               "The Sign of the Cross, the Creed, an Our Father, three Hail Marys and the Glory Be"
             )

      assert has_element?(
               view,
               "#prayer-go-to button[phx-value-page='2'][aria-current=step]",
               "Here"
             )

      assert view |> element("#prayer-go-to") |> render() |> String.split("Here") |> length() == 2
    end

    test "choosing a row goes to that part and closes", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)
      view |> element("#go-to-toggle") |> render_click()
      view |> element("#prayer-go-to button[phx-value-page='6']") |> render_click()

      assert_patch(view, path <> "?mystery=closing&step=0")
      refute has_element?(view, "#prayer-go-to")
      assert pill(view) =~ "Closing Prayers"
    end

    test "closes on Escape and on pressing the pill again", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      view |> element("#go-to-toggle") |> render_click()
      assert has_element?(view, "#prayer-go-to[phx-key=Escape]")
      render_keydown(view, "close_go_to", %{"key" => "Escape"})
      refute has_element?(view, "#prayer-go-to")

      view |> element("#go-to-toggle") |> render_click()
      assert has_element?(view, "#prayer-go-to")
      view |> element("#go-to-toggle") |> render_click()
      refute has_element?(view, "#prayer-go-to")
    end

    test "the settings pane and the list do not both stay open", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      view |> element("#go-to-toggle") |> render_click()
      view |> element("button[phx-click=toggle_panel]") |> render_click()

      refute has_element?(view, "#prayer-go-to")
      assert has_element?(view, "#prayer-settings")
    end
  end

  describe "Show Words and Beads" do
    test "is a switch in the settings pane, kept in this browser", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)
      refute has_element?(view, "[data-display=prayer-words]")

      view |> element("button[phx-click=toggle_panel]") |> render_click()

      assert has_element?(
               view,
               ~s(#prayer-display-choices button[role=switch][data-display=prayer-words][data-toggle]),
               "Show Words and Beads"
             )

      assert has_element?(view, "#prayer-display-choices", "Off, only the prayer's name stays.")
      assert has_element?(view, "#prayer-display-choices legend", "On the screen")
    end

    test "the words and the strand are marked for hiding, the name is not", %{
      conn: conn,
      path: path
    } do
      {:ok, view, _html} = live(conn, path)

      assert has_element?(view, "#bead-0 .prayer-words")
      assert has_element?(view, "#bead-status")
      refute has_element?(view, "#bead-status.prayer-words")
    end
  end
end
