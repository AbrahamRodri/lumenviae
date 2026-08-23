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
      Rosary.create_mystery(%{
        name: "Completion Mystery #{System.unique_integer([:positive])}",
        category: "joyful",
        order: System.unique_integer([:positive])
      })

    {:ok, set} =
      Rosary.create_meditation_set(%{
        name: "Completion Set #{System.unique_integer([:positive])}",
        category: "joyful"
      })

    for order <- 1..5 do
      {:ok, meditation} =
        Rosary.create_meditation(%{content: "Passage #{order}", mystery_id: mystery.id})

      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order)
    end

    set
  end

  test "walking to the last mystery records nothing", %{conn: conn} do
    set = create_set()
    before = Rosary.count_total_completions()

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

    for _ <- 1..4, do: view |> element("button[phx-click=next]") |> render_click()

    assert Rosary.count_total_completions() == before
  end

  test "jumping straight to the last mystery by URL records nothing", %{conn: conn} do
    set = create_set()
    before = Rosary.count_total_completions()

    {:ok, _view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=4")

    assert Rosary.count_total_completions() == before
  end

  test "jumping to the last mystery by bead records nothing", %{conn: conn} do
    set = create_set()
    before = Rosary.count_total_completions()

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

    view |> element("button[phx-click=go_to][phx-value-index='4']") |> render_click()

    assert Rosary.count_total_completions() == before
  end

  test "pressing Complete records one, and sends the reader back to the category", %{conn: conn} do
    set = create_set()
    before = Rosary.count_total_completions()

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=4")

    assert {:error, {:live_redirect, %{to: "/mysteries/joyful"}}} =
             view |> element("button[phx-click=complete]") |> render_click()

    assert Rosary.count_total_completions() == before + 1

    assert [%{set_id: id}] =
             Rosary.get_completions_by_set() |> Enum.filter(&(&1.set_id == set.id))

    assert id == set.id
  end

  test "the Complete button is only offered on the last mystery", %{conn: conn} do
    set = create_set()

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")
    refute has_element?(view, "button[phx-click=complete]")

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=4")
    assert has_element?(view, "button[phx-click=complete]")
  end
end
