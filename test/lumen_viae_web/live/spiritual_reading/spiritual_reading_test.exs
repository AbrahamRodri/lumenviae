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
  alias LumenViae.Rosary.SpiritualReading.LibriVox
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
        file -> Req.Test.text(conn, File.read!(Path.join(@fixtures, file)))
      end
    end)
  end

  defp stub_down, do: Req.Test.stub(Gutenberg, &Req.Test.transport_error(&1, :econnrefused))

  @librivox Path.expand("../../../support/fixtures/librivox", __DIR__)

  # Each recording's track list as LibriVox serves it, counting the
  # requests. ConnCase stubs LibriVox as down unless a test does this.
  defp stub_librivox do
    calls = :counters.new(1, [])

    Req.Test.stub(LibriVox, fn conn ->
      :counters.add(calls, 1, 1)
      conn = Plug.Conn.fetch_query_params(conn)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        File.read!(Path.join(@librivox, "feed-#{conn.query_params["id"]}.json"))
      )
    end)

    calls
  end

  describe "/spiritual-reading" do
    test "the shelf holds the five books in their cloth, and fetches nothing", %{conn: conn} do
      stub_down()
      {:ok, view, html} = live(conn, "/spiritual-reading")

      assert html =~ "Spiritual Reading"
      assert html =~ "Take up and read"
      assert html =~ "Texts from Project Gutenberg"
      assert html =~ "Classic Catholic books to read, or to listen to"
      assert html =~ "Recordings by LibriVox volunteers."

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
      assert html =~ "Text: Project Gutenberg eBook #1653."
      assert html =~ "Public domain."
      # The Imitation has no recording: no credit for one, no chips, no player.
      refute has_element?(view, "[data-role=recording-credit]")
      refute has_element?(view, "[data-act=listen]")
      refute has_element?(view, "#book-player")

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

    test "retry is ignored unless the page failed, so a client cannot loop downloads",
         %{conn: conn} do
      asked = :counters.new(1, [])
      text = File.read!(Path.join(@fixtures, "pg13871.txt"))

      Req.Test.stub(Gutenberg, fn conn ->
        :counters.add(asked, 1, 1)
        Req.Test.text(conn, text)
      end)

      {:ok, view, _html} = live(conn, "/spiritual-reading/practice-of-the-presence-of-god")
      render_async(view)
      assert has_element?(view, "[data-role=contents]")

      for _ <- 1..5, do: render_hook(view, "retry", %{})
      render_async(view)

      assert has_element?(view, "[data-role=contents]")
      assert :counters.get(asked, 1) == 1
    end

    test "Begin reading says in full where it opens", %{conn: conn} do
      stub_gutenberg()
      {:ok, view, _html} = live(conn, "/spiritual-reading/imitation-of-christ")
      render_async(view)

      assert has_element?(
               view,
               ~s([data-role=read-act][aria-label^="Begin reading, The First Book, Chapter I, Of the imitation of Christ"])
             )
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

      # One address for a chapter: no leading zero, no sign.
      for param <- ["01", "+1", "1.0"] do
        assert_error_sent 404, fn ->
          get(conn, "/spiritual-reading/practice-of-the-presence-of-god/#{param}")
        end
      end
    end

    test "found missing only after the fetch, it says so", %{conn: conn} do
      stub_gutenberg()
      {:ok, view, _html} = live(conn, "/spiritual-reading/practice-of-the-presence-of-god/99")
      render_async(view)
      assert has_element?(view, "[data-role=missing]", "No such chapter")
    end
  end

  describe "the recording" do
    test "a chapter a track reads offers Hear this read, its length, and the player",
         %{conn: conn} do
      stub_gutenberg()
      calls = stub_librivox()
      {:ok, view, _html} = live(conn, "/spiritual-reading/practice-of-the-presence-of-god/2")
      render_async(view)
      render_async(view)

      assert has_element?(view, "[data-role=hear]", "Hear this read")
      assert has_element?(view, ~s([data-role=hear][data-track="0"]))
      assert has_element?(view, ~s([data-role=hear][aria-label="Hear this chapter read"]))
      # Read whole by its own track: no "from".
      refute has_element?(view, "[data-role=hear-from]")
      assert has_element?(view, "[data-role=hear-left]", "4 MIN")

      # The player, drawn hidden for the hook, with the tracks it plays.
      assert has_element?(view, ~s(#book-player[phx-hook=BookPlayer][data-rate="1.0"]))
      assert has_element?(view, "[data-role=player][hidden]")
      assert has_element?(view, ~s([data-act=rate][data-rate="1.5"]))
      html = render(view)
      assert html =~ "practiceofpresence_01_lawrence_64kb.mp3"
      assert html =~ "Listening to this chapter"
      assert count(calls) == 1
    end

    test "Thérèse's recording is offered at her reader's pace", %{conn: conn} do
      stub_gutenberg()
      stub_librivox()
      LumenViae.Rosary.read_spiritual_book!("story-of-a-soul")
      {:ok, view, _html} = live(conn, "/spiritual-reading/story-of-a-soul/1")
      render_async(view)

      assert has_element?(view, ~s([data-role=hear][data-track="1"]))
      assert has_element?(view, ~s(#book-player[data-rate="1.5"]))
    end

    test "the preface, which the recording never reads, has no Hear this read", %{conn: conn} do
      stub_gutenberg()
      stub_librivox()
      {:ok, view, _html} = live(conn, "/spiritual-reading/practice-of-the-presence-of-god/1")
      render_async(view)
      render_async(view)

      assert has_element?(view, "#book-player")
      refute has_element?(view, "[data-role=hear]")
    end

    test "a held recording is drawn whole in the first response", %{conn: conn} do
      stub_gutenberg()
      stub_librivox()
      LumenViae.Rosary.read_spiritual_book!("practice-of-the-presence-of-god")
      LumenViae.Rosary.read_spiritual_recording!("practice-of-the-presence-of-god")

      html =
        conn |> get("/spiritual-reading/practice-of-the-presence-of-god/2") |> html_response(200)

      assert html =~ ~s(data-role="hear")
    end

    test "LibriVox out of reach leaves the chapter without Hear this read", %{conn: conn} do
      stub_gutenberg()
      {:ok, view, _html} = live(conn, "/spiritual-reading/practice-of-the-presence-of-god/2")
      render_async(view)
      render_async(view)

      assert has_element?(view, "h1", "First Conversation")
      refute has_element?(view, "[data-role=hear]")
      refute has_element?(view, "#book-player")
    end

    test "a book's rows wear the listen chip where a track opens, and the credit names LibriVox",
         %{conn: conn} do
      stub_gutenberg()
      stub_librivox()
      {:ok, view, _html} = live(conn, "/spiritual-reading/practice-of-the-presence-of-god")
      render_async(view)
      render_async(view)

      # Nineteen tracks for twenty chapters: the preface has none.
      assert view |> element("#contents-listening") |> render() =~ "First Conversation"
      refute has_element?(view, ~s([data-act=listen][data-chapter="0"]))
      assert has_element?(view, ~s([data-act=listen][data-chapter="1"][data-track="0"]), "4 MIN")

      assert has_element?(
               view,
               ~s([data-act=listen][aria-label="Hear First Conversation read"])
             )

      assert length(Regex.scan(~r/data-act="listen"/, render(view))) == 19
      assert has_element?(view, "[data-role=recording-credit]", "Recording: LibriVox volunteers.")
      assert has_element?(view, "#book-player[phx-hook=BookPlayer]")
    end

    test "LibriVox out of reach says so on the book's page, with Try again", %{conn: conn} do
      stub_gutenberg()
      {:ok, view, _html} = live(conn, "/spiritual-reading/practice-of-the-presence-of-god")
      render_async(view)
      render_async(view)

      assert has_element?(
               view,
               "[data-role=recording-unavailable]",
               "The recording couldn't be reached."
             )

      refute has_element?(view, "[data-act=listen]")
      # The text is whole without it.
      assert has_element?(view, "[data-role=chapter-row]")

      calls = stub_librivox()
      # Held for a while after the failure: Try again asks the server, which
      # answers from the hold without asking LibriVox again.
      view |> element("[data-role=retry-recording]") |> render_click()
      render_async(view)
      assert count(calls) == 0
    end

    test "retry_recording is ignored unless the recording failed", %{conn: conn} do
      stub_gutenberg()
      calls = stub_librivox()
      {:ok, view, _html} = live(conn, "/spiritual-reading/practice-of-the-presence-of-god")
      render_async(view)
      render_async(view)

      for _ <- 1..5, do: render_hook(view, "retry_recording", %{})
      assert count(calls) == 1
      assert has_element?(view, "[data-act=listen]")
    end
  end

  defp count(calls), do: :counters.get(calls, 1)

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

  # How many chapters the catalogue's rules cut each whole edition into
  # (November 2026; iOS's parser gives the same). Brother Lawrence's is
  # checked against its whole edition in the fixtures; the others are the
  # full texts' counts, kept here so the sitemap cannot drift from them.
  @cut_counts %{
    "imitation-of-christ" => 115,
    "story-of-a-soul" => 13,
    "confessions-of-st-augustine" => 13,
    "glories-of-mary" => 58,
    "practice-of-the-presence-of-god" => 20
  }

  test "the sitemap lists each book's chapters 1 to its count, no more, no gap" do
    sitemap = File.read!("priv/static/sitemap.xml")

    listed =
      ~r{<loc>https://www\.lumenviae\.org/spiritual-reading/([a-z-]+)/(\d+)</loc>}
      |> Regex.scan(sitemap)
      |> Enum.group_by(fn [_all, id, _n] -> id end, fn [_all, _id, n] -> String.to_integer(n) end)

    assert Map.keys(listed) |> Enum.sort() == Map.keys(@cut_counts) |> Enum.sort()

    for {id, count} <- @cut_counts do
      assert Enum.sort(listed[id]) == Enum.to_list(1..count), "#{id}'s chapters in the sitemap"
    end

    stub_gutenberg()
    lawrence = LumenViae.Rosary.read_spiritual_book!("practice-of-the-presence-of-god")

    assert length(lawrence.contents) == @cut_counts["practice-of-the-presence-of-god"]
  end

  test "the privacy policy says the server fetches the books and the place stays in the browser",
       %{conn: conn} do
    {:ok, _view, html} = live(conn, "/privacy-policy")
    assert html =~ ~r/fetched from Project Gutenberg by\s+our own server/
    assert html =~ "kept in your own browser"
    assert html =~ ~r/track list is fetched from LibriVox\s+by our own server/
    assert html =~ ~r/loaded from the\s+Internet Archive by your browser/
  end
end
