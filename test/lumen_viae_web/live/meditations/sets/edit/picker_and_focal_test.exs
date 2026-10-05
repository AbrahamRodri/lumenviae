defmodule LumenViaeWeb.Live.Meditations.Sets.Edit.PickerAndFocalTest do
  @moduledoc """
  Two parts of the set editor that `FormTest` does not drive: the "Add a
  meditation" picker, narrowed by its filters, with positions held to the
  seven a set has; and the focal point the `FocalPoint` hook sends when
  the curator clicks the painting.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Set #{System.unique_integer([:positive])}", category: "joyful"},
        actor: admin()
      )

    {:ok, conn: log_in_admin(conn), set: set}
  end

  defp create_meditation(category, attrs) do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Mystery #{System.unique_integer([:positive])}",
          category: category,
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(Map.merge(%{content: "Text.", mystery_id: mystery.id}, attrs),
        actor: admin()
      )

    meditation
  end

  defp option_ids(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find(~s(select[name="meditation_id"] option))
    |> Enum.flat_map(&Floki.attribute(&1, "value"))
    |> Enum.reject(&(&1 == ""))
  end

  defp filter(view, params) do
    view
    |> form(
      "#meditation-filters",
      Map.merge(%{"category" => "", "author" => "", "query" => ""}, params)
    )
    |> render_change()
  end

  describe "the meditation picker" do
    setup do
      %{
        bernard:
          create_meditation("joyful", %{title: "Honey of the Word", author: "St. Bernard"}),
        liguori:
          create_meditation("joyful", %{title: "The Crib", author: "St. Alphonsus Liguori"}),
        sorrowful:
          create_meditation("sorrowful", %{title: "In the Garden", author: "St. Bernard"})
      }
    end

    test "offers every meditation until it is narrowed", %{conn: conn, set: set} = ctx do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      ids = option_ids(view)

      for meditation <- [ctx.bernard, ctx.liguori, ctx.sorrowful] do
        assert to_string(meditation.id) in ids
      end
    end

    test "narrows by category", %{conn: conn, set: set} = ctx do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      filter(view, %{"category" => "sorrowful"})
      ids = option_ids(view)

      assert to_string(ctx.sorrowful.id) in ids
      refute to_string(ctx.bernard.id) in ids
      refute to_string(ctx.liguori.id) in ids
    end

    test "narrows by author, and by category and author together",
         %{conn: conn, set: set} = ctx do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      filter(view, %{"author" => "St. Bernard"})

      assert Enum.sort(option_ids(view)) ==
               Enum.sort([to_string(ctx.bernard.id), to_string(ctx.sorrowful.id)])

      filter(view, %{"author" => "St. Bernard", "category" => "joyful"})
      assert option_ids(view) == [to_string(ctx.bernard.id)]
    end

    test "narrows by a search of the title", %{conn: conn, set: set} = ctx do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      filter(view, %{"query" => "  crib  "})

      assert option_ids(view) == [to_string(ctx.liguori.id)]
    end

    test "says so when nothing matches, and offers no form to submit",
         %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      html = filter(view, %{"query" => "nothing is called this"})

      assert html =~ "No meditations match these filters"
      refute has_element?(view, ~s(select[name="meditation_id"]))
    end

    test "flags an archived meditation as one that would hide the set",
         %{conn: conn, set: set} = ctx do
      {:ok, _} = Rosary.archive_meditation(ctx.liguori, actor: admin())

      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      assert view
             |> element(~s(option[value="#{ctx.liguori.id}"]))
             |> render() =~ "Archived - adding it hides this set"
    end

    test "suggests the next free position", %{conn: conn, set: set} = ctx do
      {:ok, _} = Rosary.add_meditation_to_set(set.id, ctx.bernard.id, 1, actor: admin())

      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      assert has_element?(view, ~s(input[name="order"][value="2"]))
    end
  end

  describe "positions" do
    for order <- ["0", "8", "two", ""] do
      test "refuses position #{inspect(order)} and adds nothing", %{conn: conn, set: set} do
        meditation = create_meditation("joyful", %{})
        {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

        html =
          render_submit(view, "add_to_set", %{
            "meditation_id" => to_string(meditation.id),
            "order" => unquote(order)
          })

        assert html =~ "Invalid meditation ID or order (must be 1-7)"
        assert Rosary.list_meditations_in_set(set.id, actor: admin()) == []
      end
    end

    test "accepts the seventh, the last a set has", %{conn: conn, set: set} do
      meditation = create_meditation("joyful", %{title: "The Seventh"})
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      html =
        render_submit(view, "add_to_set", %{
          "meditation_id" => to_string(meditation.id),
          "order" => "7"
        })

      assert html =~ "Meditation added to set"
      assert [%{title: "The Seventh"}] = Rosary.list_meditations_in_set(set.id, actor: admin())
    end
  end

  describe "the focal point" do
    defp reload(set), do: Rosary.get_meditation_set!(set.id, actor: admin())

    test "is saved where the curator clicked", %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      render_hook(view, "set_focal_point", %{"x" => 0.25, "y" => 0.8})

      saved = reload(set)
      assert saved.image_focal_x == 0.25
      assert saved.image_focal_y == 0.8
    end

    test "a point off the painting is refused, and the saved one kept",
         %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")
      render_hook(view, "set_focal_point", %{"x" => 0.3, "y" => 0.3})

      html = render_hook(view, "set_focal_point", %{"x" => 1.5, "y" => -0.2})

      assert html =~ "Failed to move the focal point"
      saved = reload(set)
      assert saved.image_focal_x == 0.3
      assert saved.image_focal_y == 0.3
    end

    test "a nudge never pushes it past the edge", %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")
      render_hook(view, "set_focal_point", %{"x" => 0.95, "y" => 0.05})

      render_click(view, "nudge_focal", %{"axis" => "x", "delta" => "0.1"})
      render_click(view, "nudge_focal", %{"axis" => "y", "delta" => "-0.1"})

      saved = reload(set)
      assert saved.image_focal_x == 1.0
      assert saved.image_focal_y == 0.0
    end

    test "an unreadable nudge changes nothing", %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")
      render_hook(view, "set_focal_point", %{"x" => 0.4, "y" => 0.6})

      render_click(view, "nudge_focal", %{"axis" => "x", "delta" => "left"})

      assert reload(set).image_focal_x == 0.4
    end
  end
end
