defmodule LumenViaeWeb.Live.Home.LearnPagesTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # The phx-value-index of every devotion currently expanded in the
  # true/false devotion accordion.
  defp expanded_devotions(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find("button[phx-click='toggle-devotion'][aria-expanded='true']")
    |> Enum.flat_map(&Floki.attribute(&1, "phx-value-index"))
  end

  # Collapses the template's line wrapping so prose assertions do not depend
  # on where the formatter happened to break a sentence.
  defp squish(html), do: String.replace(html, ~r/\s+/, " ")

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
    for {name, path} <- [
          {"rosary methods", "/rosary-methods"},
          {"true devotion", "/true-devotion"},
          {"saint carlo", "/saint-carlo"},
          {"mysteries in scripture", "/mysteries"}
        ] do
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

    test "selecting a tab moves the focusable tab with it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/saint-carlo")

      html = view |> element("button[phx-value-moment='assisi']") |> render_click()

      tab =
        Floki.parse_document!(html)
        |> Floki.find("#moment-tab-assisi")

      assert Floki.attribute(tab, "tabindex") == ["0"]
      assert Floki.attribute(tab, "aria-selected") == ["true"]
    end

    test "step tabs announce their title, not a bare number", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/rosary-methods")

      assert html =~ ~s(aria-label="Step 1: The Sign of the Cross and the Creed")
    end
  end

  describe "How to Pray the Rosary (/rosary-methods)" do
    test "renders the guide with the interactive first step", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/rosary-methods")

      assert html =~ "How to Pray the Rosary"
      assert html =~ "The Sign of the Cross and the Creed"
      assert html =~ "I believe in God, the Father Almighty"
    end

    test "selecting a step shows its prayers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/rosary-methods")

      html =
        view
        |> element("button[phx-value-step='7'][role='tab']")
        |> render_click()

      assert html =~ "Close the Decade"
      assert html =~ "O my Jesus, forgive us our sins"
    end

    test "method one offers all fifteen decades across the three sets", %{conn: conn} do
      {:ok, view, html} = live(conn, "/rosary-methods")

      # Joyful shown by default, with the corrected fifth decade petition
      assert html =~ "this first decade in honor of Thine Incarnation"
      assert html =~ "our own conversion and the conversion of all sinners"

      sorrowful_html =
        view
        |> element("button[phx-value-set='sorrowful']")
        |> render_click()

      assert sorrowful_html =~ "Sixth Decade"
      assert sorrowful_html =~ "mortal Agony in the Garden of Olives"

      glorious_html =
        view
        |> element("button[phx-value-set='glorious']")
        |> render_click()

      assert glorious_html =~ "Fifteenth Decade"
      assert glorious_html =~ "O Holy Ghost, this thirteenth decade"
    end

    test "includes the fifteen promises", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/rosary-methods")

      assert html =~ "The Fifteen Promises of the Rosary"
      assert html =~ "Devotion to my Rosary is a great sign of predestination."
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

  describe "True Devotion to Mary (/true-devotion)" do
    test "renders the teaching and the consecration", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/true-devotion")

      assert html =~ "True Devotion to Mary"
      assert html =~ "To Jesus through Mary"
      assert html =~ "The 33-Day Preparation"
      assert html =~ "I deliver and consecrate to thee"
    end

    test "switches between true and false devotion", %{conn: conn} do
      {:ok, view, html} = live(conn, "/true-devotion")

      # True marks shown by default
      assert html =~ "Interior"
      refute html =~ "The Critical Devotees"

      false_html =
        view
        |> element("button[phx-value-tab='false']")
        |> render_click()

      assert false_html =~ "The Critical Devotees"
      assert false_html =~ "The Interested Devotees"
    end

    test "expands one devotion at a time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/true-devotion")

      assert expanded_devotions(view) == ["1"]

      # Opening another mark closes the one that was open.
      view |> element("button[phx-value-index='3']") |> render_click()
      assert expanded_devotions(view) == ["3"]

      # Clicking the open mark collapses it, leaving none expanded.
      view |> element("button[phx-value-index='3']") |> render_click()
      assert expanded_devotions(view) == []

      # Switching tabs starts the new list from its first item.
      view |> element("button[phx-value-tab='false']") |> render_click()
      assert expanded_devotions(view) == ["1"]
    end

    test "dates the prophecy against the Revolution correctly", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/true-devotion")

      # The treatise was written c. 1712; the manuscript was hidden in the
      # 1790s. That is roughly eighty years, not more than a century.
      assert html =~ "written some eighty years"
      refute html =~ "written more than a century"
    end

    test "selects preparation phases", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/true-devotion")

      html =
        view
        |> element("button[phx-value-phase='week2']")
        |> render_click()

      assert html =~ "Knowledge of the Blessed Virgin"
    end
  end

  describe "St. Carlo Acutis (/saint-carlo)" do
    test "renders the biography and icon", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/saint-carlo")

      assert html =~ "Saint Carlo Acutis"
      assert html =~ "Icon of St. Carlo Acutis"
      assert html =~ "The Eucharist is my highway to heaven."
    end

    test "does not credit Carlo with a smartphone he never owned", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/saint-carlo")
      prose = squish(html)

      # He died in October 2006, before the first smartphone shipped.
      refute prose =~ "smartphone generation"
      assert prose =~ "He died before the first smartphone"
      assert prose =~ "one hour of video games a week"
    end

    test "dates the Eucharistic miracles exhibition to when he began it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/saint-carlo")

      html = view |> element("button[phx-value-moment='exhibition']") |> render_click()

      assert html =~ "At eleven, Carlo sets himself to catalogue"
      # The often-repeated "opened in Rome on October 4, 2006" conflates the
      # exhibition with the unveiling of his website.
      refute html =~ "opens in Rome"
    end

    test "selects timeline moments", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/saint-carlo")

      html =
        view
        |> element("button[phx-value-moment='canonization']")
        |> render_click()

      assert html =~ "Pope Leo XIV canonizes Carlo Acutis"
      assert html =~ "September 7, 2025"
    end
  end
end
