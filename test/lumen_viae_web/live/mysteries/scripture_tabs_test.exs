defmodule LumenViaeWeb.Live.Mysteries.ScriptureTabsTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Every `role="tab"` must point at an element that is really a tabpanel.
  # Without the pairing, `aria-selected` announces a state about nothing.
  defp orphan_tabs(html) do
    doc = Floki.parse_document!(html)
    panel_ids = doc |> Floki.find("[role='tabpanel']") |> Floki.attribute("id") |> MapSet.new()

    doc
    |> Floki.find("[role='tab']")
    |> Enum.reject(fn tab ->
      tab
      |> Floki.attribute("aria-controls")
      |> List.first()
      |> then(&MapSet.member?(panel_ids, &1))
    end)
    |> Enum.map(&(Floki.attribute(&1, "id") |> List.first()))
  end

  # A tablist is one stop in the tab order: exactly one tab carries
  # tabindex="0" and the rest are removed with -1, so Tab moves past the whole
  # group and the arrow keys move within it.
  defp roving_tabindex(html) do
    Floki.parse_document!(html)
    |> Floki.find("[role='tablist']")
    |> Enum.map(fn list ->
      tabs = Floki.find(list, "[role='tab']")
      indexes = Enum.map(tabs, &(Floki.attribute(&1, "tabindex") |> List.first()))
      {Floki.attribute(list, "aria-label") |> List.first(), Enum.frequencies(indexes)}
    end)
  end

  describe "tab widgets" do
    for {name, path} <- [{"mysteries in scripture", "/mysteries"}] do
      test "every tab on the #{name} page controls a tabpanel", %{conn: conn} do
        {:ok, _view, html} = live(conn, unquote(path))

        assert orphan_tabs(html) == []
        assert html =~ ~s(role="tabpanel")
      end

      test "every tablist on the #{name} page is one tab stop", %{conn: conn} do
        {:ok, _view, html} = live(conn, unquote(path))
        lists = roving_tabindex(html)

        assert lists != []

        for {label, counts} <- lists do
          assert Map.get(counts, "0") == 1,
                 "#{label} should have exactly one focusable tab, got #{inspect(counts)}"

          # Every other tab is explicitly removed from the tab order.
          refute Map.has_key?(counts, nil), "#{label} has a tab with no tabindex"
        end
      end

      test "every tablist on the #{name} page has the keyboard hook", %{conn: conn} do
        {:ok, _view, html} = live(conn, unquote(path))

        lists =
          Floki.parse_document!(html)
          |> Floki.find("[role='tablist']")

        for list <- lists do
          assert Floki.attribute(list, "phx-hook") == ["Tablist"]
          refute Floki.attribute(list, "id") == []
        end
      end
    end
  end

  describe "Finding the Mysteries in Scripture (/mysteries)" do
    test "renders with fruits of the mysteries", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/mysteries")

      assert html =~ "Finding the Mysteries in Scripture"
      assert html =~ "Fruit of the Mystery: Humility"
    end

    test "shows the Seven Sorrows category", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries")

      html =
        view
        |> element("button[phx-value-id='seven_sorrows']")
        |> render_click()

      assert html =~ "The Seven Sorrows of Mary"
      assert html =~ "The Prophecy of Simeon"
      assert html =~ "thy own soul a sword shall pierce"
    end
  end
end
