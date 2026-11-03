defmodule LumenViaeWeb.Live.TrueDevotionTest do
  @moduledoc """
  True Devotion's public pages: the book's title page at `/true-devotion`
  and a chapter at `/true-devotion/:chapter_id`, from
  `priv/library/true_devotion.json`. What the reader keeps (the place,
  the chapters read, the bookmarks) is the browser's and is not here.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary
  alias LumenViaeWeb.Live.TrueDevotion.Book

  setup do
    %{book: Rosary.get_true_devotion!(load: [:about, :parts, :chapters])}
  end

  describe "/true-devotion" do
    test "is the book's title page, no longer a redirect home", %{conn: conn, book: book} do
      conn = get(conn, "/true-devotion")
      html = html_response(conn, 200)

      assert html =~ book.about.title
      assert html =~ book.about.author
      assert html =~ book.about.translator
      assert html =~ book.about.source_note
    end

    test "opens on Begin reading at the first chapter, the act the hook may turn", %{
      conn: conn,
      book: book
    } do
      {:ok, view, html} = live(conn, "/true-devotion")
      first = hd(book.chapters)

      assert html |> Floki.parse_document!() |> Floki.find("main h1") |> length() == 1
      assert has_element?(view, ~s([data-role=read-act][href="/true-devotion/#{first.id}"]))
      assert view |> element("[data-role=act-kicker]") |> render() =~ "Begin reading"
      assert view |> element("[data-role=act-destination]") |> render() =~ first.title
      assert has_element?(view, "#true-devotion[phx-hook=TrueDevotionPlace][data-page=book]")
    end

    test "lists every chapter, the Introduction first, then each part, the first open", %{
      conn: conn,
      book: book
    } do
      {:ok, view, html} = live(conn, "/true-devotion")
      doc = Floki.parse_document!(html)

      assert doc |> Floki.find("[data-role=chapter-row]") |> Floki.attribute("data-chapter") ==
               Enum.map(book.chapters, & &1.id)

      assert view |> element("#contents-heading") |> render() =~
               "Contents · #{length(book.chapters)} chapters"

      assert doc |> Floki.find("details[data-part] .td-part__name") |> Enum.map(&Floki.text/1) ==
               ["Part I", "Part II"]

      assert doc |> Floki.find("details[data-part][open]") |> Floki.attribute("data-part") ==
               ["1"]

      for chapter <- book.chapters do
        [count] =
          doc
          |> Floki.find(~s([data-role=chapter-row][data-chapter="#{chapter.id}"]))
          |> Floki.attribute("data-paragraphs")

        assert String.to_integer(count) == Enum.count(chapter.paragraphs, &(&1.kind == "text"))
      end
    end

    test "carries the book's structured data and canonical link", %{conn: conn} do
      html = conn |> get("/true-devotion") |> html_response(200)

      assert html =~ ~s(<link rel="canonical" href="https://www.lumenviae.org/true-devotion")
      assert html =~ ~s("@type":"Book")
    end

    test "leaves out the archived summary page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/true-devotion")

      refute html =~ "The Devotion in Summary"
      refute html =~ "Short Prayers"
    end
  end

  describe "/true-devotion/:chapter_id" do
    test "reads a chapter in place, its paragraphs numbered and anchored", %{
      conn: conn,
      book: book
    } do
      chapter = Enum.find(book.chapters, &(&1.id == "motives"))
      {:ok, view, html} = live(conn, "/true-devotion/motives")
      doc = Floki.parse_document!(html)

      assert view |> element("h1") |> render() =~ chapter.title
      assert view |> element("[data-role=kicker]") |> render() =~ "Part II"
      assert view |> element("[data-role=chapter-place]") |> render() =~ "8 of 13"

      texts = Enum.filter(chapter.paragraphs, &(&1.kind == "text"))
      paragraphs = Floki.find(doc, "[data-role=chapter-text] p[data-p]")

      assert length(paragraphs) == length(texts)
      assert Floki.attribute(paragraphs, "id") == Enum.map(1..length(texts), &"p-#{&1}")

      # Its sub-headings are headings, not numbered paragraphs.
      subheadings = Enum.filter(chapter.paragraphs, &(&1.kind == "subheading"))

      assert doc |> Floki.find("[data-role=chapter-text] h2") |> length() ==
               length(subheadings)

      assert html =~ "Paragraph 1: bookmark or share"
    end

    test "steps to the chapters either side", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/true-devotion/necessity")

      assert has_element?(
               view,
               ~s([data-role=previous-chapter][href="/true-devotion/introduction"])
             )

      assert has_element?(view, ~s([data-role=next-chapter][href="/true-devotion/discernment"]))

      {:ok, _view, html} =
        view |> element("[data-role=next-chapter]") |> render_click() |> follow_redirect(conn)

      assert html =~ "Five Fundamental Truths"
    end

    test "the Introduction has no chapter before; the last ends the book", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/true-devotion/introduction")
      refute has_element?(view, "[data-role=previous-chapter]")

      assert view |> element("[data-role=kicker]") |> render() =~
               "True Devotion to the Blessed Virgin"

      {:ok, view, _html} = live(conn, "/true-devotion/formula")
      refute has_element?(view, "[data-role=next-chapter]")
      assert view |> element("[data-role=finis]") |> render() =~ "The End"
    end

    test "the contents mark this chapter Here, in the rail and the jump list", %{conn: conn} do
      {:ok, view, html} = live(conn, "/true-devotion/figure")
      doc = Floki.parse_document!(html)

      current = Floki.find(doc, ~s(.td-contents__link[aria-current="page"]))
      assert current |> Floki.attribute("data-chapter") == ["figure", "figure"]
      assert has_element?(view, "[data-role=rail]")
      assert has_element?(view, "[data-role=jump-list]")
    end

    test "carries the chapter's title, description and structured data", %{conn: conn} do
      html = conn |> get("/true-devotion/consists") |> html_response(200)

      assert html =~
               ~s(<meta property="og:title" content="What Perfect Consecration Consists In, True Devotion">)

      assert html =~
               ~s(<link rel="canonical" href="https://www.lumenviae.org/true-devotion/consists")

      assert html =~ ~s("@type":"Chapter")
    end

    test "an unknown chapter is a 404", %{conn: conn} do
      for path <- ["/true-devotion/nowhere", "/true-devotion/%00", "/true-devotion/0"] do
        error = assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, path) end
        assert Plug.Exception.status(error) == 404
      end
    end

    test "a query the page does not read never breaks it", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/true-devotion/effects?p[]=3&chapter_id[x]=1")
      assert html =~ "Wonderful Effects of This Devotion"
    end
  end

  describe "Book" do
    test "numbers a chapter's text paragraphs from 1, its versal on a long opening",
         %{book: book} do
      chapter = Enum.find(book.chapters, &(&1.id == "motives"))
      blocks = Book.blocks(chapter)

      assert hd(blocks).kind == :subheading
      texts = Enum.filter(blocks, &(&1.kind == :text))
      assert Enum.map(texts, & &1.number) == Enum.to_list(1..length(texts))
      assert [%{number: 1, versal?: true} | rest] = texts
      refute Enum.any?(rest, & &1.versal?)
    end

    test "no versal on a short opening or one that opens on a quotation mark" do
      short = %{paragraphs: [%{id: 0, kind: "text", text: "Brief."}]}
      quoted = %{paragraphs: [%{id: 0, kind: "text", text: "“" <> String.duplicate("a", 100)}]}

      assert [%{versal?: false}] = Book.blocks(short)
      assert [%{versal?: false}] = Book.blocks(quoted)
    end

    test "names a part short, and cites a chapter as the app's share does", %{book: book} do
      loaded = %Book{about: book.about, parts: book.parts, chapters: book.chapters}

      assert Book.short_part_title(hd(book.parts)) == "Part I"

      assert Book.citation(loaded, hd(book.chapters)) ==
               "— #{book.about.author}, #{book.about.title}, Introduction (trans. Fr. Frederick William Faber). Public domain."
    end

    test "finds no chapter for an id that is not a string", %{book: book} do
      loaded = %Book{about: book.about, parts: book.parts, chapters: book.chapters}

      assert Book.chapter(loaded, nil) == nil
      assert Book.chapter(loaded, ["motives"]) == nil
      assert Book.chapter(loaded, "motives").id == "motives"
    end
  end

  describe "the sitemap" do
    test "lists the title page and every chapter", %{book: book} do
      sitemap = File.read!(Application.app_dir(:lumen_viae, "priv/static/sitemap.xml"))

      assert sitemap =~ "<loc>https://www.lumenviae.org/true-devotion</loc>"

      for chapter <- book.chapters do
        assert sitemap =~ "<loc>https://www.lumenviae.org/true-devotion/#{chapter.id}</loc>"
      end
    end
  end
end
