defmodule LumenViaeWeb.Live.Meditations.ListActionsTest do
  @moduledoc """
  The meditation list's row and selection controls that `ListTest` does
  not drive: reading a meditation in place, deleting one, clearing the
  filters and the selection, and restoring archived meditations in bulk.
  Also the category filter on the new-meditation form's mystery list.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  defp create_mystery(attrs \\ %{}) do
    defaults = %{
      name: "Mystery #{System.unique_integer([:positive])}",
      category: "joyful",
      order: System.unique_integer([:positive])
    }

    {:ok, mystery} = Rosary.create_mystery(Map.merge(defaults, attrs), actor: admin())
    mystery
  end

  defp create_meditation(mystery, attrs) do
    {:ok, meditation} =
      Rosary.create_meditation(Map.merge(%{content: "Text.", mystery_id: mystery.id}, attrs),
        actor: admin()
      )

    meditation
  end

  defp toggle_button(id), do: "button[phx-click=toggle_meditation][phx-value-id='#{id}']"

  describe "reading a meditation in place" do
    test "opens and closes its full text and source", %{conn: conn} do
      meditation =
        create_meditation(create_mystery(), %{
          title: "On Humility",
          content: "Consider how the Virgin answered the angel.",
          source: "The Glories of Mary"
        })

      {:ok, view, html} = live(conn, "/admin/meditations")
      refute html =~ "Consider how the Virgin answered the angel."

      html = view |> element(toggle_button(meditation.id)) |> render_click()
      assert html =~ "Consider how the Virgin answered the angel."

      assert has_element?(
               view,
               ~s(#{toggle_button(meditation.id)}[aria-label="Collapse meditation"])
             )

      html = view |> element(toggle_button(meditation.id)) |> render_click()
      refute html =~ "Consider how the Virgin answered the angel."
      assert has_element?(view, ~s(#{toggle_button(meditation.id)}[aria-label="Read meditation"]))
    end

    test "opening one closes the other", %{conn: conn} do
      mystery = create_mystery()
      first = create_meditation(mystery, %{content: "The first passage."})
      second = create_meditation(mystery, %{content: "The second passage."})

      {:ok, view, _html} = live(conn, "/admin/meditations")

      view |> element(toggle_button(first.id)) |> render_click()
      html = view |> element(toggle_button(second.id)) |> render_click()

      assert html =~ "The second passage."
      refute html =~ "The first passage."
    end
  end

  describe "deleting one meditation" do
    test "removes it from the list and the database, and from its set", %{conn: conn} do
      mystery = create_mystery()
      doomed = create_meditation(mystery, %{title: "Title Doomed"})
      kept = create_meditation(mystery, %{title: "Title Kept"})

      {:ok, set} =
        Rosary.create_meditation_set(%{name: "Holding Set", category: "joyful"}, actor: admin())

      {:ok, _} = Rosary.add_meditation_to_set(set.id, doomed.id, 1, actor: admin())

      {:ok, view, _html} = live(conn, "/admin/meditations")

      html =
        view
        |> element("button[phx-click=delete_meditation][phx-value-id='#{doomed.id}']")
        |> render_click()

      assert html =~ "Meditation deleted successfully"
      refute html =~ "Title Doomed"
      assert html =~ "Title Kept"
      assert {:error, %Ash.Error.Invalid{}} = Rosary.get_meditation(doomed.id, actor: admin())
      assert Rosary.get_meditation!(kept.id, actor: admin())
      assert Rosary.list_meditations_in_set(set.id, actor: admin()) == []
    end

    test "asks before it deletes", %{conn: conn} do
      meditation = create_meditation(create_mystery(), %{})

      {:ok, view, _html} = live(conn, "/admin/meditations")

      assert has_element?(
               view,
               "button[phx-click=delete_meditation][phx-value-id='#{meditation.id}'][data-confirm]"
             )
    end
  end

  describe "clearing" do
    test "Clear filters returns to the unfiltered list", %{conn: conn} do
      mystery = create_mystery()
      create_meditation(mystery, %{title: "Title Found", content: "Humility"})
      create_meditation(mystery, %{title: "Title Other", content: "Charity"})

      {:ok, view, html} = live(conn, "/admin/meditations?q=humility")
      refute html =~ "Title Other"

      view |> element("button[phx-click=clear_filters]") |> render_click()
      assert_patch(view, "/admin/meditations")

      html = render(view)
      assert html =~ "Title Found"
      assert html =~ "Title Other"
      refute has_element?(view, "button[phx-click=clear_filters]")
    end

    test "Clear selection unselects, so a bulk action has nothing to act on",
         %{conn: conn} do
      meditation = create_meditation(create_mystery(), %{})

      {:ok, view, _html} = live(conn, "/admin/meditations")

      view |> element("button[phx-click=select_all_shown]") |> render_click()
      assert render(view) =~ "1 selected"

      view |> element("button[phx-click=clear_selection]") |> render_click()

      refute has_element?(view, "button[phx-click=bulk_delete]")
      assert Rosary.get_meditation!(meditation.id, actor: admin())
    end

    test "clicking a selected row's box again unselects it", %{conn: conn} do
      meditation = create_meditation(create_mystery(), %{})
      box = "input[type=checkbox][phx-value-id='#{meditation.id}']"

      {:ok, view, _html} = live(conn, "/admin/meditations")

      view |> element(box) |> render_click()
      assert render(view) =~ "1 selected"

      view |> element(box) |> render_click()
      refute render(view) =~ "1 selected"
      refute has_element?(view, "button[phx-click=bulk_archive]")
    end
  end

  describe "bulk restore" do
    test "brings back only the archived ones among the selection", %{conn: conn} do
      mystery = create_mystery()
      archived = create_meditation(mystery, %{title: "Title Archived"})
      also_archived = create_meditation(mystery, %{title: "Title Also Archived"})
      {:ok, _} = Rosary.archive_meditation(archived, actor: admin())
      {:ok, _} = Rosary.archive_meditation(also_archived, actor: admin())

      {:ok, view, _html} = live(conn, "/admin/meditations?status=all")

      view |> element("button[phx-click=select_all_shown]") |> render_click()
      html = view |> element("button[phx-click=bulk_unarchive]") |> render_click()

      assert html =~ "2 meditations restored."
      refute Rosary.get_meditation!(archived.id, actor: admin()).archived_at
      refute Rosary.get_meditation!(also_archived.id, actor: admin()).archived_at
    end

    test "counts nothing when nothing selected was archived", %{conn: conn} do
      active = create_meditation(create_mystery(), %{})

      {:ok, view, _html} = live(conn, "/admin/meditations")

      view |> element("input[type=checkbox][phx-value-id='#{active.id}']") |> render_click()
      html = view |> element("button[phx-click=bulk_unarchive]") |> render_click()

      assert html =~ "0 meditations restored."
      refute Rosary.get_meditation!(active.id, actor: admin()).archived_at
    end
  end

  describe "the new meditation form's category filter" do
    defp mystery_options(view) do
      view
      |> render()
      |> Floki.parse_document!()
      |> Floki.find(~s(select[name="meditation[mystery_id]"] option))
      |> Enum.flat_map(&Floki.attribute(&1, "value"))
    end

    test "narrows the mystery list to one category, and widens it again", %{conn: conn} do
      joyful = create_mystery(%{name: "The Visitation Test", category: "joyful"})
      sorrowful = create_mystery(%{name: "The Agony Test", category: "sorrowful"})

      {:ok, view, _html} = live(conn, "/admin/meditations/new")
      assert to_string(joyful.id) in mystery_options(view)
      assert to_string(sorrowful.id) in mystery_options(view)

      view |> form("#mystery-category-filter", %{"category" => "sorrowful"}) |> render_change()
      assert to_string(sorrowful.id) in mystery_options(view)
      refute to_string(joyful.id) in mystery_options(view)

      view |> form("#mystery-category-filter", %{"category" => ""}) |> render_change()
      assert to_string(joyful.id) in mystery_options(view)
    end
  end
end
