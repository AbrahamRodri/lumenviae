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

      assert view |> element("[data-role=seasonal-card]") |> render() =~ "This season<"
      assert has_element?(view, ~s([data-role=marian-card][href="/prayers/memorare"]))
      refute has_element?(view, ~s([data-role=marian-card][href="/prayers/hail_mary"]))
    end

    test "everyday rows carry no Latin second line, as the app's", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers")

      refute view |> element(~s([data-role=everyday-row][href="/prayers/our_father"])) |> render() =~
               "Pater Noster"
    end

    test "the Litany's card on Mary's shelf has no line the app does not give", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers")

      card =
        view |> element(~s([data-role=marian-card][href="/prayers/litany_loreto"])) |> render()

      refute card =~ "book-card__note"
    end

    test "All Topics shelves every topic under the book's five parts, with its count", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, "/prayers")
      doc = Floki.parse_document!(html)

      assert doc |> Floki.find("[data-role=book-part] h3") |> Enum.map(&Floki.text/1) == [
               "Every Day",
               "The Sacraments",
               "God, Our Lady and the Saints",
               "Through the Year",
               "For Others, and in Need"
             ]

      assert view |> element("[data-role=topic-tile]", "The Blessed Virgin") |> render() =~
               ~r{href="/prayers/topics/our_lady"}

      assert length(Floki.find(doc, "[data-role=topic-tile]")) == 18
      assert length(Floki.find(doc, "[data-role=topic-tile] .book-card__painting img")) == 18
      refute html =~ "Jesus present in the Host"
    end

    test "a q that is not text is no search, not a crash", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prayers?q[x]=1")

      assert html =~ "Everyday Prayers"
    end

    test "a search event that is not text is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers")

      assert render_hook(view, "search", %{"q" => %{"x" => "1"}}) =~ "Everyday Prayers"
    end

    test "the visitor's offset sets the day for the season's song", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers")

      assert render_hook(view, "set_timezone", %{"offset" => 300}) =~ "This season"
      assert render_hook(view, "set_timezone", %{"offset" => "nonsense"}) =~ "This season"
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
    test "a topic heads itself with its painting, title and line, and lists its prayers", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/prayers/topics/day")
      html = render(view)

      assert view |> element("h1") |> render() =~ "Daily Prayers"
      assert view |> element("[data-role=chapter-note]") |> render() =~ "Morning, the Angelus"
      assert has_element?(view, ".book-hero__painting img")
      refute html =~ "Preces Quotidianæ"
      refute html =~ "Chapter II"

      for section <- ["In the morning", "The Angelus", "At meals", "At night"] do
        assert has_element?(view, "h2", section)
      end

      assert has_element?(
               view,
               ~s([data-role=chapter-prayer][href="/prayers/angelus"] .book-row__card img)
             )
    end

    test "the foot is the next topic's card and a line back to the one before", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/topics/day")

      assert view |> element("[data-role=next-topic]") |> render() =~ "Short Prayers"

      assert view |> element("[data-role=next-topic]") |> render() =~
               ~s(href="/prayers/topics/short")

      assert view |> element("[data-role=previous-topic]") |> render() =~
               ~r{or back to.*The First Prayers}s

      refute has_element?(view, "[data-role=next-topic]", "Chapter")
    end

    test "the last topic has no next card, the first no line back", %{conn: conn} do
      {:ok, last, _html} = live(conn, "/prayers/topics/needs")
      refute has_element?(last, "[data-role=next-topic]")

      {:ok, first, _html} = live(conn, "/prayers/topics/first")
      refute has_element?(first, "[data-role=previous-topic]")
    end

    test "a topic of one section has no sub-heading", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/topics/st_joseph")

      refute has_element?(view, "h2")
      assert has_element?(view, "[data-role=chapter-prayer]")
    end

    test "Our Lady's topic marks the season's song", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/topics/our_lady")

      assert has_element?(view, "[data-role=this-season]", "This season")
    end

    test "an unknown chapter is a 404", %{conn: conn} do
      error =
        assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/prayers/topics/nowhere") end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "/prayers/:prayer_id" do
    test "a prayer is in English, headed as the app heads it", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers/memorare")

      assert view |> element("h1") |> render() =~ "The Memorare"

      assert view |> element("[data-role=second-title]") |> render() =~
               "Remember, O most gracious"

      assert html =~ "Remember, O most gracious Virgin Mary,"
      refute view |> element("[data-role=prayer-text]") |> render() =~ "O piissima Virgo"
      refute html =~ "Fr Claude Bernard"
      refute html =~ "When It Is Said"
      assert view |> element("[data-role=home-chapter]") |> render() =~ "The Blessed Virgin"
      assert has_element?(view, ~s([data-role=language] a[aria-current]), "English")
      refute has_element?(view, "a[rel=prev]")
      refute has_element?(view, "a[rel=next]")
    end

    test "the Latin name heads only a prayer known by it", %{conn: conn} do
      {:ok, named, _html} = live(conn, "/prayers/our_father")
      assert named |> element("[data-role=second-title]") |> render() =~ "Pater Noster"

      {:ok, faith, _html} = live(conn, "/prayers/act_of_faith")
      refute has_element?(faith, "[data-role=second-title]")
    end

    test "a psalm verse breaks at its mediant", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/magnificat?lang=latin")

      assert has_element?(view, "[data-role=mediant] .book-glyph", "*")
      assert has_element?(view, ".book-verse--second")
    end

    test "a long prose prayer opens on a versal, verse does not", %{conn: conn} do
      {:ok, prose, _html} = live(conn, "/prayers/morning_offering")
      assert has_element?(prose, ".book-stanza--versal")

      {:ok, verse, _html} = live(conn, "/prayers/memorare")
      refute has_element?(verse, ".book-stanza--versal")
    end

    test "?lang=latin sets the Latin alone", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/memorare?lang=latin")
      text = view |> element("[data-role=prayer-text]") |> render()

      assert text =~ "O piissima Virgo Maria"
      assert text =~ ~s(lang="la")
      refute text =~ "Remember, O most gracious Virgin Mary,"
    end

    test "?lang=both pairs the English with its Latin", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers/memorare?lang=both")

      assert html =~ "O piissima Virgo Maria"
      assert html =~ "Remember, O most gracious Virgin Mary,"
      assert has_element?(view, ".book-line--paired .book-line__secondary[lang=la]")
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
