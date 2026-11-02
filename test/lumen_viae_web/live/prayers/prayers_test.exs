defmodule LumenViaeWeb.Live.Prayers.PrayersTest do
  @moduledoc """
  The Prayer Book's public pages: `/prayers` (the shelves, All Topics and
  the search in `?q=`), a chapter at `/prayers/topics/:chapter_id` and a
  prayer at `/prayers/:prayer_id` with its language in `?lang=`. The book
  is the one in `priv/library/prayer_book.json`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "/prayers" do
    test "heads the book with its count and opens on the app's shelves", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers")

      assert html =~ "<h1"
      assert view |> element("[data-role=prayer-count]") |> render() =~ ~r/\d+ prayers/
      assert html =~ "Everyday Prayers"
      assert html =~ "Prayers to Mary"
      assert html =~ "All Topics"

      for path <-
            ~w(/prayers/our_father /prayers/hail_mary /prayers/glory_be /prayers/apostles_creed) do
        assert has_element?(view, ~s([data-role=everyday-row][href="#{path}"]))
      end

      assert has_element?(view, "[data-role=seasonal-card]", "This season's song to Mary")
      assert has_element?(view, ~s([data-role=marian-card][href="/prayers/memorare"]))
      refute has_element?(view, ~s([data-role=marian-card][href="/prayers/hail_mary"]))
    end

    test "lists every chapter under All Topics, with its count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers")

      assert view |> element("[data-role=topic-row]", "The Blessed Virgin") |> render() =~
               ~r{href="/prayers/topics/our_lady"}

      assert has_element?(view, "[data-role=topic-row]", "Jesus present in the Host")

      assert view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("[data-role=topic-row]")
             |> length() == 18
    end

    test "?q=memorare finds the Memorare first", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers?q=memorare")

      refute html =~ "Everyday Prayers"

      [first | _] =
        html |> Floki.parse_document!() |> Floki.find("[data-role=result-row]")

      assert Floki.attribute(first, "href") == ["/prayers/memorare"]
      assert view |> element("[data-role=match-count]") |> render() =~ ~r/prayers? match/
    end

    test "typing in the field puts the search in the link", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers")

      view |> form("#prayer-search", q: "joseph") |> render_change()

      assert_patched(view, "/prayers?q=joseph")
      assert has_element?(view, "[data-role=result-row]", "St Joseph")
    end

    test "a search that names a topic shows it as a card", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers?q=litanies")

      assert has_element?(view, ~s([data-role=topic-card][href="/prayers/topics/litanies"]))
    end

    test "nonsense finds nothing and says so", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers?q=zzqxv")

      assert view |> element("[data-role=no-match]") |> render() =~ "No prayer by that name."
      refute has_element?(view, "[data-role=result-row]")
    end
  end

  describe "/prayers/topics/:chapter_id" do
    test "a chapter heads itself and lists its prayers under its sections", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers/topics/day")

      assert view |> element("[data-role=chapter-numeral]") |> render() =~ "Chapter II"
      assert view |> element("h1") |> render() =~ "Daily Prayers"
      assert html =~ "Preces Quotidianæ"

      for section <- ["In the morning", "The Angelus", "At meals", "At night"] do
        assert has_element?(view, "h2", section)
      end

      assert has_element?(view, ~s([data-role=chapter-prayer][href="/prayers/angelus"]))
      assert has_element?(view, ~s(a[href="/prayers/topics/short"]), "Short Prayers")
    end

    test "an unknown chapter is a 404", %{conn: conn} do
      error =
        assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/prayers/topics/nowhere") end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "/prayers/:prayer_id" do
    test "a prayer is in English, with its names, note and chapter", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers/memorare")

      assert view |> element("h1") |> render() =~ "The Memorare"
      assert html =~ "Remember, O most gracious Virgin Mary,"
      refute view |> element("[data-role=prayer-text]") |> render() =~ "O piissima Virgo"
      assert view |> element("[data-role=note]") |> render() =~ "Fr Claude Bernard"
      assert view |> element("[data-role=home-chapter]") |> render() =~ "The Blessed Virgin"
      assert has_element?(view, ~s([data-role=language] a[aria-current]), "English")
      assert has_element?(view, "a[rel=prev]")
      assert has_element?(view, "a[rel=next]")
    end

    test "?lang=latin sets the Latin alone", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/memorare?lang=latin")
      text = view |> element("[data-role=prayer-text]") |> render()

      assert text =~ "O piissima Virgo Maria"
      assert text =~ ~s(lang="la")
      refute text =~ "Remember, O most gracious Virgin Mary,"
    end

    test "?lang=both pairs the Latin with its English", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers/memorare?lang=both")

      assert html =~ "O piissima Virgo Maria"
      assert html =~ "Remember, O most gracious Virgin Mary,"
      assert has_element?(view, ".prayer-line--paired .prayer-line__secondary[lang=en]")
      assert has_element?(view, ~s([data-role=language] a[aria-current]), "Both")
    end

    test "the chooser patches the language into the link, English left out", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/memorare")

      view |> element("[data-role=language] a", "Both") |> render_click()
      assert_patched(view, "/prayers/memorare?lang=both")

      view |> element("[data-role=language] a", "English") |> render_click()
      assert_patched(view, "/prayers/memorare")
    end

    test "a rubric is set as a rubric", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/nicene_creed")

      assert view |> element("[data-role=rubric]") |> render() =~ "Here all genuflect."
      refute view |> element("[data-role=prayer-text]") |> render() =~ "[Here all genuflect.]"
    end

    test "an unknown prayer is a 404", %{conn: conn} do
      error =
        assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/prayers/not_a_prayer") end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "the sitemap" do
    test "lists /prayers and every chapter's page" do
      sitemap = File.read!(Application.app_dir(:lumen_viae, "priv/static/sitemap.xml"))
      book = LumenViaeWeb.Live.Prayers.Book.load(nil)

      assert sitemap =~ "<loc>https://www.lumenviae.org/prayers</loc>"

      for chapter <- book.chapters do
        assert sitemap =~ "<loc>https://www.lumenviae.org/prayers/topics/#{chapter.id}</loc>"
      end
    end
  end
end
