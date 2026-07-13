defmodule LumenViaeWeb.Live.Meditations.ListTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: Plug.Test.init_test_session(conn, %{admin_authenticated: true})}
  end

  defp create_mystery(attrs \\ %{}) do
    defaults = %{
      name: "Test Mystery #{System.unique_integer([:positive])}",
      category: "joyful",
      order: System.unique_integer([:positive])
    }

    {:ok, mystery} = Rosary.create_mystery(Map.merge(defaults, attrs))
    mystery
  end

  defp create_meditation(mystery, attrs \\ %{}) do
    defaults = %{content: "Test meditation content", mystery_id: mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs))
    meditation
  end

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Test Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  test "requires an admin session", %{conn: _conn} do
    conn = build_conn()
    assert {:error, {:redirect, %{to: "/admin/login"}}} = live(conn, "/admin/meditations")
  end

  test "lists meditations with status badges", %{conn: conn} do
    mystery = create_mystery(%{name: "Mystery Alpha"})
    create_meditation(mystery, %{author: "Fulton Sheen"})

    {:ok, _view, html} = live(conn, "/admin/meditations")

    assert html =~ "Mystery Alpha"
    assert html =~ "Fulton Sheen"
    assert html =~ "No audio"
    assert html =~ "Not in a set"
  end

  # Assertions use meditation titles: mystery and set names also appear in the
  # filter dropdown options, so they match every page render.
  test "status filter in the URL narrows the list to archived meditations", %{conn: conn} do
    mystery = create_mystery()
    create_meditation(mystery, %{title: "Title Active"})
    archived = create_meditation(mystery, %{title: "Title Archived"})
    {:ok, _} = Rosary.archive_meditation(archived)

    {:ok, _view, html} = live(conn, "/admin/meditations?status=archived")

    assert html =~ "Title Archived"
    refute html =~ "Title Active"
  end

  test "audio filter narrows to meditations missing audio", %{conn: conn} do
    mystery = create_mystery()
    create_meditation(mystery, %{title: "Title Voiced", audio_url: "voiced.mp3"})
    create_meditation(mystery, %{title: "Title Silent"})

    {:ok, _view, html} = live(conn, "/admin/meditations?audio=without")

    assert html =~ "Title Silent"
    refute html =~ "Title Voiced"
  end

  test "set filter supports membership and none", %{conn: conn} do
    mystery = create_mystery()
    in_set = create_meditation(mystery, %{title: "Title Grouped"})
    create_meditation(mystery, %{title: "Title Orphan"})
    set = create_set()
    {:ok, _} = Rosary.add_meditation_to_set(set.id, in_set.id, 1)

    {:ok, _view, html} = live(conn, "/admin/meditations?set=none")
    assert html =~ "Title Orphan"
    refute html =~ "Title Grouped"

    {:ok, _view, html} = live(conn, "/admin/meditations?set=#{set.id}")
    assert html =~ "Title Grouped"
    refute html =~ "Title Orphan"
  end

  test "changing a filter patches the URL", %{conn: conn} do
    mystery = create_mystery()
    create_meditation(mystery, %{content: "Consider the humility of Mary"})

    {:ok, view, _html} = live(conn, "/admin/meditations")

    view
    |> element("form[phx-change=update_filters]")
    |> render_change(%{"q" => "humility", "status" => "active"})

    assert_patch(view, "/admin/meditations?q=humility&status=active")
  end

  test "search matches content text", %{conn: conn} do
    mystery = create_mystery()
    create_meditation(mystery, %{title: "Title Match", content: "Consider the humility of Mary"})
    create_meditation(mystery, %{title: "Title Other", content: "A different passage"})

    {:ok, _view, html} = live(conn, "/admin/meditations?q=humility")

    assert html =~ "Title Match"
    refute html =~ "Title Other"
  end

  test "archive and unarchive from the list", %{conn: conn} do
    mystery = create_mystery()
    meditation = create_meditation(mystery)

    {:ok, view, _html} = live(conn, "/admin/meditations")

    view
    |> element("button[phx-click=archive_meditation][phx-value-id='#{meditation.id}']")
    |> render_click()

    assert Rosary.get_meditation!(meditation.id).archived_at
    assert render(view) =~ "Archived"

    view
    |> element("button[phx-click=unarchive_meditation][phx-value-id='#{meditation.id}']")
    |> render_click()

    refute Rosary.get_meditation!(meditation.id).archived_at
  end

  test "bulk archive applies to all shown meditations", %{conn: conn} do
    mystery = create_mystery()
    first = create_meditation(mystery)
    second = create_meditation(mystery)

    {:ok, view, _html} = live(conn, "/admin/meditations")

    view |> element("button[phx-click=select_all_shown]") |> render_click()
    html = view |> element("button[phx-click=bulk_archive]") |> render_click()

    assert html =~ "2 meditations archived."
    assert Rosary.get_meditation!(first.id).archived_at
    assert Rosary.get_meditation!(second.id).archived_at
  end
end
