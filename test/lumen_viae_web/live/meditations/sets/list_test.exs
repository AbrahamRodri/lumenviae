defmodule LumenViaeWeb.Live.Meditations.Sets.ListTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: Plug.Test.init_test_session(conn, %{admin_authenticated: true})}
  end

  defp create_mystery do
    {:ok, mystery} =
      Rosary.create_mystery(%{
        name: "Test Mystery #{System.unique_integer([:positive])}",
        category: "joyful",
        order: System.unique_integer([:positive])
      })

    mystery
  end

  defp create_meditation(mystery, attrs \\ %{}) do
    defaults = %{content: "Test meditation content", mystery_id: mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs))
    meditation
  end

  defp create_set(attrs) do
    defaults = %{name: "Test Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  test "lists sets with completeness badges", %{conn: conn} do
    mystery = create_mystery()
    filled = create_set(%{name: "Filled Set"})
    create_set(%{name: "Empty Set"})

    for order <- 1..5 do
      meditation = create_meditation(mystery)
      {:ok, _} = Rosary.add_meditation_to_set(filled.id, meditation.id, order)
    end

    {:ok, view, html} = live(conn, "/admin/meditation-sets")

    assert html =~ "Filled Set"
    assert html =~ "5 meditations"
    assert html =~ "Empty Set"
    assert has_element?(view, "span", "Empty")
  end

  test "visibility filter separates hidden sets", %{conn: conn} do
    mystery = create_mystery()
    hidden_set = create_set(%{name: "Hidden Set"})
    create_set(%{name: "Visible Set"})

    meditation = create_meditation(mystery)
    {:ok, _} = Rosary.add_meditation_to_set(hidden_set.id, meditation.id, 1)
    {:ok, _} = Rosary.archive_meditation(meditation)

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?visibility=hidden")
    assert html =~ "Hidden Set"
    refute html =~ "Visible Set"

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?visibility=visible")
    assert html =~ "Visible Set"
    refute html =~ "Hidden Set"
  end

  test "label filter matches sets carrying the label", %{conn: conn} do
    create_set(%{name: "Saints Set", labels: ["Saints"]})
    create_set(%{name: "Plain Set"})

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?label=Saints")

    assert html =~ "Saints Set"
    refute html =~ "Plain Set"
  end

  test "expanding a set shows its ordered meditations inline", %{conn: conn} do
    mystery = create_mystery()
    set = create_set(%{name: "Expandable Set"})
    meditation = create_meditation(mystery, %{title: "Unique Expanded Title"})
    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)

    {:ok, view, html} = live(conn, "/admin/meditation-sets")
    refute html =~ "Unique Expanded Title"

    html =
      view
      |> element("button[phx-click=toggle_expand][phx-value-id='#{set.id}']")
      |> render_click()

    assert html =~ "Unique Expanded Title"
  end

  test "deleting a set removes it from the list", %{conn: conn} do
    set = create_set(%{name: "Deletable Set"})

    {:ok, view, _html} = live(conn, "/admin/meditation-sets")

    html =
      view
      |> element("button[phx-click=delete_set][phx-value-id='#{set.id}']")
      |> render_click()

    refute html =~ "Deletable Set"
    assert Rosary.list_meditation_sets() |> Enum.map(& &1.id) |> Enum.member?(set.id) == false
  end
end
