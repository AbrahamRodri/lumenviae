defmodule LumenViaeWeb.Live.SpiritualReading.SpiritualReadingTest do
  @moduledoc """
  The Spiritual Reading pages: the shelf (`/spiritual-reading`), a book's
  page (`/spiritual-reading/:book_id`) and a chapter
  (`/spiritual-reading/:book_id/:chapter`). Everything is real but the
  wire to Project Gutenberg, which Req.Test answers with the editions in
  `test/support/fixtures/gutenberg`. Not async: the books' text is held in
  one table for the whole machine, emptied before each test.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary.SpiritualReading.Gutenberg
  alias LumenViae.Rosary.SpiritualReading.Text

  @moduletag :capture_log

  @fixtures Path.expand("../../../support/fixtures/gutenberg", __DIR__)

  setup do
    Text.reset()
    on_exit(&Text.reset/0)
    :ok
  end

  # Each book's edition as Gutenberg serves it (the excerpts the parser
  # tests read), by ebook number.
  defp stub_gutenberg do
    texts = %{
      "1653" => "pg1653-excerpt.txt",
      "13871" => "pg13871.txt",
      "16772" => "pg16772-excerpt.txt",
      "72411" => "pg72411-excerpt.txt"
    }

    Req.Test.stub(Gutenberg, fn conn ->
      [_cache, _epub, id | _rest] = conn.path_info

      case texts[id] do
        nil -> Plug.Conn.send_resp(conn, 404, "")
        file -> Plug.Conn.send_resp(conn, 200, File.read!(Path.join(@fixtures, file)))
      end
    end)
  end

  defp stub_down, do: Req.Test.stub(Gutenberg, &Req.Test.transport_error(&1, :econnrefused))

  describe "/spiritual-reading" do
    test "the shelf holds the five books in their cloth, and fetches nothing", %{conn: conn} do
      stub_down()
      {:ok, view, html} = live(conn, "/spiritual-reading")

      assert html =~ "Spiritual Reading"
      assert html =~ "Take up and read"
      assert html =~ "Texts from Project Gutenberg"

      for id <-
            ~w(imitation-of-christ story-of-a-soul confessions-of-st-augustine glories-of-mary practice-of-the-presence-of-god) do
        assert has_element?(view, ~s(a[data-role=book][href="/spiritual-reading/#{id}"]))
        assert has_element?(view, ".sr-cloth--#{id}")
      end

      refute html =~ "/true-devotion"
    end
  end

  describe "a book's page" do
    test "fetches the text once connected, then shows Begin reading and the contents by part",
         %{conn: conn} do
      stub_gutenberg()
      conn = get(conn, "/spiritual-reading/imitation-of-christ")
      # The first response does not wait on Gutenberg.
      assert html_response(conn, 200) =~ "Fetching the text from Project Gutenberg"

      {:ok, view, _html} = live(conn)
      html = render_async(view)

      assert html =~ "The Imitation of Christ"
      assert has_element?(view, "h1", "The Imitation of Christ")

      assert has_element?(
               view,
               ~s([data-role=read-act][href="/spiritual-reading/imitation-of-christ/1"]),
               "Begin reading"
             )

      assert has_element?(view, ".sr-part", "The First Book")
      assert has_element?(view, ".sr-part", "The Fourth Book")
      # The excerpt holds two of the four books: the index numbers them as
      # the page counts its parts, as the app's does.
      assert has_element?(view, ~s([data-role=part-index] a[href="#part-2"]), "II")
      assert html =~ "Text: Project Gutenberg eBook #1653. Public domain."

      # The Fourth Book's exhortation is named by its part's numeral alone.
      assert has_element?(view, ~s([data-role=chapter-row][data-short="II"]))
      assert has_element?(view, ~s([data-role=chapter-row][data-short="I.I"]))
    end

    test "a book the server already holds is drawn whole in the first response", %{conn: conn} do
      stub_gutenberg()
      LumenViae.Rosary.read_spiritual_book!("practice-of-the-presence-of-god")

      html =
        conn |> get("/spiritual-reading/practice-of-the-presence-of-god") |> html_response(200)

      assert html =~ "Contents · 20 chapters"
      assert html =~ "First Conversation"
      refute html =~ "Fetching the text"
    end

    test "Gutenberg out of reach says so with Try again", %{conn: conn} do
      stub_down()
      {:ok, view, _html} = live(conn, "/spiritual-reading/story-of-a-soul")
      render_async(view)

      assert has_element?(view, "[data-role=unavailable]", "Couldn't reach the library")
      assert has_element?(view, "[data-role=retry]")

      stub_gutenberg()
      Text.reset()
      view |> element("[data-role=retry]") |> render_click()
      render_async(view)
      assert has_element?(view, "[data-role=contents]")
    end

    test "an unknown book is a 404", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, "/spiritual-reading/nowhere") end
    end
  end

  describe "a chapter" do
    test "is read with its kicker, place, notes and the chapters either side", %{conn: conn} do
      stub_gutenberg()
      {:ok, view, _html} = live(conn, "/spiritual-reading/imitation-of-christ/1")
      html = render_async(view)

      assert has_element?(view, "h1", "Of the imitation of Christ")
      assert has_element?(view, "[data-role=kicker]", "The First Book · Chapter I")
      assert has_element?(view, "[data-role=chapter-place]")

      # The footnote markers link to the apparatus at the foot.
      assert has_element?(view, ~s(.sr-mark a[href="#note-1"]))
      assert has_element?(view, "#note-1")
      assert has_element?(view, "#notes-heading", "Notes")

      # The first chapter has no chapter before it.
      refute has_element?(view, "[data-role=previous-chapter]")

      assert has_element?(
               view,
               ~s([data-role=next-chapter][href="/spiritual-reading/imitation-of-christ/2"])
             )

      # The contents, this chapter marked Here.
      assert html =~ "Here"
      assert has_element?(view, ~s(#rail [aria-current=page][data-chapter="0"]))
    end

    test "a held book's chapter is drawn whole at once, named in its title", %{conn: conn} do
      stub_gutenberg()
      LumenViae.Rosary.read_spiritual_book!("practice-of-the-presence-of-god")

      html =
        conn |> get("/spiritual-reading/practice-of-the-presence-of-god/2") |> html_response(200)

      assert html =~
               ~s(<meta property="og:title" content="First Conversation, The Practice of the Presence of God">)

      assert html =~ ~s(data-role="previous-chapter")
      assert html =~ ~s(id="p-1")
    end

    test "a chapter the book does not have is a 404, once its contents are known", %{conn: conn} do
      stub_gutenberg()
      LumenViae.Rosary.read_spiritual_book!("practice-of-the-presence-of-god")

      assert_error_sent 404, fn ->
        get(conn, "/spiritual-reading/practice-of-the-presence-of-god/21")
      end

      assert_error_sent 404, fn ->
        get(conn, "/spiritual-reading/practice-of-the-presence-of-god/0")
      end

      assert_error_sent 404, fn ->
        get(conn, "/spiritual-reading/practice-of-the-presence-of-god/one")
      end
    end

    test "found missing only after the fetch, it says so", %{conn: conn} do
      stub_gutenberg()
      {:ok, view, _html} = live(conn, "/spiritual-reading/practice-of-the-presence-of-god/99")
      render_async(view)
      assert has_element?(view, "[data-role=missing]", "No such chapter")
    end
  end

  test "the sitemap lists the shelf, every book and every chapter of the books held here" do
    sitemap = File.read!("priv/static/sitemap.xml")
    assert sitemap =~ "<loc>https://www.lumenviae.org/spiritual-reading</loc>"

    for id <-
          ~w(imitation-of-christ story-of-a-soul confessions-of-st-augustine glories-of-mary practice-of-the-presence-of-god) do
      assert sitemap =~ "<loc>https://www.lumenviae.org/spiritual-reading/#{id}</loc>"
      assert sitemap =~ "<loc>https://www.lumenviae.org/spiritual-reading/#{id}/1</loc>"
    end

    # Brother Lawrence's whole edition is a fixture: every chapter is listed.
    for n <- 1..20 do
      assert sitemap =~
               "<loc>https://www.lumenviae.org/spiritual-reading/practice-of-the-presence-of-god/#{n}</loc>"
    end

    refute sitemap =~ "practice-of-the-presence-of-god/21<"
  end

  test "the privacy policy says the server fetches the books and the place stays in the browser",
       %{conn: conn} do
    {:ok, _view, html} = live(conn, "/privacy-policy")
    assert html =~ ~r/fetched from Project Gutenberg by\s+our own server/
    assert html =~ "kept in your own browser"
  end
end
