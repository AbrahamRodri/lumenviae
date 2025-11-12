defmodule LumenViaeWeb.Live.Pray.IndexTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, joyful_one} =
      Rosary.create_mystery(%{
        name: "The Annunciation",
        category: "joyful",
        order: 1,
        description: "Mary learns she will bear the Son of God."
      })

    {:ok, joyful_two} =
      Rosary.create_mystery(%{
        name: "The Visitation",
        category: "joyful",
        order: 2,
        description: "Mary visits Elizabeth."
      })

    {:ok, meditation_one} =
      Rosary.create_meditation(%{
        title: "Meditation One",
        content: "Reflect on Mary's fiat.",
        mystery_id: joyful_one.id
      })

    {:ok, meditation_two} =
      Rosary.create_meditation(%{
        title: "Meditation Two",
        content: "Consider the joy of Elizabeth.",
        mystery_id: joyful_two.id
      })

    {:ok, set} =
      Rosary.create_meditation_set(%{
        name: "Joyful Reflections",
        category: "joyful",
        description: "A sample set for testing."
      })

    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation_one.id, 1)
    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation_two.id, 2)

    set = Rosary.get_meditation_set_with_ordered_meditations!(set.id)

    {:ok,
     conn: conn,
     set: set,
     meditation_one: meditation_one,
     meditation_two: meditation_two}
  end

  test "advancing to the next mystery updates the displayed meditation", %{
    conn: conn,
    set: set,
    meditation_one: meditation_one,
    meditation_two: meditation_two
  } do
    {:ok, view, html} = live(conn, ~p"/meditation-sets/#{set.id}/pray")

    assert html =~ meditation_one.content

    html = render_click(view, "next")

    assert html =~ meditation_two.content
    refute html =~ meditation_one.content
  end

  test "returning to the previous mystery shows the prior meditation", %{
    conn: conn,
    set: set,
    meditation_one: meditation_one,
    meditation_two: meditation_two
  } do
    {:ok, view, _html} = live(conn, ~p"/meditation-sets/#{set.id}/pray")

    render_click(view, "next")
    html = render_click(view, "previous")

    assert html =~ meditation_one.content
    refute html =~ meditation_two.content
  end

  test "restoring progress jumps to the requested meditation", %{
    conn: conn,
    set: set,
    meditation_two: meditation_two
  } do
    {:ok, view, _html} = live(conn, ~p"/meditation-sets/#{set.id}/pray")

    html =
      view
      |> element("#rosary-progress-container")
      |> render_hook("restore_progress", %{"index" => 1})

    assert html =~ meditation_two.content
  end
end
