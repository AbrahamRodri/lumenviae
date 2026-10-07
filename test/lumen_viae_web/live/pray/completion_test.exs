defmodule LumenViaeWeb.Live.Pray.CompletionTest do
  @moduledoc """
  A completion must cost a deliberate press.

  It used to be recorded the moment the last mystery came into view, which
  anything walking the site reached for free - so the analytics counted
  crawlers as people who had prayed a Rosary. These tests pin the fix: no
  count for navigating, one count for pressing Complete, and never two.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  defp create_set do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Completion Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    {:ok, set} =
      Rosary.create_meditation_set(
        %{
          name: "Completion Set #{System.unique_integer([:positive])}",
          category: "joyful"
        },
        actor: admin()
      )

    for order <- 1..5 do
      {:ok, meditation} =
        Rosary.create_meditation(%{content: "Passage #{order}", mystery_id: mystery.id},
          actor: admin()
        )

      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order, actor: admin())
    end

    set
  end

  test "walking to the closing prayers records nothing", %{conn: conn} do
    set = create_set()
    before = Rosary.count_total_completions(actor: admin())

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

    for _ <- 1..6, do: view |> element("button[phx-click=next]") |> render_click()

    assert Rosary.count_total_completions(actor: admin()) == before
  end

  test "jumping straight to the closing prayers by URL records nothing", %{conn: conn} do
    set = create_set()
    before = Rosary.count_total_completions(actor: admin())

    {:ok, _view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=closing")

    assert Rosary.count_total_completions(actor: admin()) == before
  end

  test "jumping to the closing prayers by the strand records nothing", %{conn: conn} do
    set = create_set()
    before = Rosary.count_total_completions(actor: admin())

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

    view |> element("button[phx-click=go_to][phx-value-page='6']") |> render_click()

    assert Rosary.count_total_completions(actor: admin()) == before
  end

  test "pressing Complete records one, and shows the Rosary offered", %{conn: conn} do
    set = create_set()
    before = Rosary.count_total_completions(actor: admin())

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=closing")

    html = view |> element("button[phx-click=complete]") |> render_click()

    assert html =~ "The Rosary is offered"
    assert html =~ "Amen"
    assert has_element?(view, "#prayer-complete[phx-hook=PrayerStreak]")
    assert has_element?(view, ~s(a[href="/mysteries/joyful"]), "Back to the Joyful Mysteries")
    assert has_element?(view, ~s(a[href="/"]))
    refute has_element?(view, "button[phx-click=complete]")

    assert Rosary.count_total_completions(actor: admin()) == before + 1

    assert [%{set_id: id}] =
             Rosary.get_completions_by_set(actor: admin()) |> Enum.filter(&(&1.set_id == set.id))

    assert id == set.id
  end

  test "pressing it twice still records one", %{conn: conn} do
    set = create_set()
    before = Rosary.count_total_completions(actor: admin())

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=closing")
    render_click(view, "complete", %{})
    render_click(view, "complete", %{})

    assert Rosary.count_total_completions(actor: admin()) == before + 1
  end

  test "the Complete button is only offered on the closing prayers", %{conn: conn} do
    set = create_set()

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")
    refute has_element?(view, "button[phx-click=complete]")

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=4")
    refute has_element?(view, "button[phx-click=complete]")

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=closing")
    assert has_element?(view, "button[phx-click=complete]")
  end
end
