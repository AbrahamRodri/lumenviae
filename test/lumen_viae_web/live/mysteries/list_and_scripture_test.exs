defmodule LumenViaeWeb.Live.Mysteries.ListAndScriptureTest do
  @moduledoc """
  The admin mystery list's filters and meditation counts, which
  `AdminTest` does not drive, and the public Scripture page's choice of
  category, by link and by tab.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  defp create_mystery(attrs) do
    defaults = %{
      name: "Mystery #{System.unique_integer([:positive])}",
      category: "joyful",
      order: System.unique_integer([:positive])
    }

    {:ok, mystery} = Rosary.create_mystery(Map.merge(defaults, attrs), actor: admin())
    mystery
  end

  defp create_meditation(mystery) do
    {:ok, meditation} =
      Rosary.create_meditation(%{content: "Text.", mystery_id: mystery.id}, actor: admin())

    meditation
  end

  defp edit_link(mystery), do: ~s(a[href="/admin/mysteries/#{mystery.id}/edit"])

  defp counts_cell(view, mystery) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find("tr")
    |> Enum.find(&(Floki.find(&1, edit_link(mystery)) != []))
    |> Floki.find("td")
    |> Enum.at(4)
    |> Floki.text()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  describe "the admin mystery list's filters" do
    setup %{conn: conn} do
      %{
        conn: log_in_admin(conn),
        annunciation:
          create_mystery(%{
            name: "The Annunciation Test",
            description: "Gabriel greets the Virgin",
            scripture_reference: "Luke 1:26-38"
          }),
        agony:
          create_mystery(%{
            name: "The Agony Test",
            category: "sorrowful",
            scripture_reference: "Matthew 26:36-46"
          })
      }
    end

    test "search matches the name, the description and the scripture",
         %{conn: conn} = ctx do
      for {query, found, missing} <- [
            {"annunciation", ctx.annunciation, ctx.agony},
            {"GABRIEL", ctx.annunciation, ctx.agony},
            {"matthew 26", ctx.agony, ctx.annunciation}
          ] do
        {:ok, view, _html} = live(conn, "/admin/mysteries?q=#{URI.encode_www_form(query)}")

        assert has_element?(view, edit_link(found)), "#{query} should find #{found.name}"
        refute has_element?(view, edit_link(missing)), "#{query} should not find #{missing.name}"
      end
    end

    test "the category narrows the list and goes into the URL", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, "/admin/mysteries")

      view
      |> form("#mysteries-filters", %{"q" => "", "category" => "sorrowful"})
      |> render_change()

      assert_patch(view, "/admin/mysteries?category=sorrowful")
      assert has_element?(view, edit_link(ctx.agony))
      refute has_element?(view, edit_link(ctx.annunciation))
    end

    test "an unknown category in the URL is ignored", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, "/admin/mysteries?category=cheerful")

      assert has_element?(view, edit_link(ctx.agony))
      assert has_element?(view, edit_link(ctx.annunciation))
      refute has_element?(view, "button[phx-click=clear_filters]")
    end

    test "says so when nothing matches, and Clear filters brings everything back",
         %{conn: conn} = ctx do
      {:ok, view, html} = live(conn, "/admin/mysteries?q=no+such+mystery")
      assert html =~ "No mysteries match these filters."

      view |> element("button[phx-click=clear_filters]") |> render_click()
      assert_patch(view, "/admin/mysteries")

      assert has_element?(view, edit_link(ctx.annunciation))
      assert has_element?(view, edit_link(ctx.agony))
    end
  end

  describe "the admin mystery list's meditation counts" do
    setup %{conn: conn}, do: %{conn: log_in_admin(conn)}

    test "a mystery with nothing written is marked None", %{conn: conn} do
      bare = create_mystery(%{})

      {:ok, view, _html} = live(conn, "/admin/mysteries")

      assert counts_cell(view, bare) == "None"
    end

    test "counts active meditations, and the total when some are archived",
         %{conn: conn} do
      mystery = create_mystery(%{})
      create_meditation(mystery)
      create_meditation(mystery)
      {:ok, _} = Rosary.archive_meditation(create_meditation(mystery), actor: admin())

      {:ok, view, _html} = live(conn, "/admin/mysteries")

      assert counts_cell(view, mystery) == "2 of 3"
    end

    test "only archived meditations count as None", %{conn: conn} do
      mystery = create_mystery(%{})
      {:ok, _} = Rosary.archive_meditation(create_meditation(mystery), actor: admin())

      {:ok, view, _html} = live(conn, "/admin/mysteries")

      assert counts_cell(view, mystery) == "None"
    end

    test "links to the meditation list filtered to that mystery", %{conn: conn} do
      mystery = create_mystery(%{})

      {:ok, view, _html} = live(conn, "/admin/mysteries")

      assert has_element?(view, ~s(a[href="/admin/meditations?mystery=#{mystery.id}"]))
    end
  end

  describe "the Scripture page (/mysteries)" do
    defp selected_tab(view) do
      view
      |> render()
      |> Floki.parse_document!()
      |> Floki.find(~s(#category-tablist [aria-selected="true"]))
      |> Enum.flat_map(&Floki.attribute(&1, "phx-value-id"))
    end

    test "opens on the Joyful Mysteries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries")

      assert selected_tab(view) == ["joyful"]
    end

    test "a link can open it on another category", %{conn: conn} do
      {:ok, view, html} = live(conn, "/mysteries?category=sorrowful")

      assert selected_tab(view) == ["sorrowful"]
      assert html =~ "Fruit of the Mystery: Contrition for Sin"
    end

    test "an unknown category in the link falls back to Joyful", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries?category=cheerful")

      assert selected_tab(view) == ["joyful"]
    end

    test "each tab shows its own category", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries")

      for category <- ~w(sorrowful glorious luminous seven_sorrows joyful) do
        view |> element("#category-tab-#{category}") |> render_click()
        assert selected_tab(view) == [category]
      end
    end

    test "an unknown tab keeps the one already open", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries?category=glorious")

      render_click(view, "select-category", %{"id" => "cheerful"})

      assert selected_tab(view) == ["glorious"]
    end
  end
end
