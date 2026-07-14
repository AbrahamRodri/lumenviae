defmodule LumenViaeWeb.Live.Home.LearnPagesTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

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
