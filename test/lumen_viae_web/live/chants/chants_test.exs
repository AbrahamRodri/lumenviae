defmodule LumenViaeWeb.Live.Chants.ChantsTest do
  @moduledoc """
  The Chant Library's public pages: `/chant` (the Mass of the Angels'
  tile, Songs to Mary, the sections and the search in `?q=`), a shelf at
  `/chant/sections/:section_id` and a chant at `/chant/:chant_id` with its
  words in `?words=`. The library is the one in
  `priv/library/chant_library.json`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Chants.Library

  describe "/chant" do
    test "heads the library with its count, the Mass tile, Songs to Mary and every section",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/chant")
      library = Library.load(nil)

      assert html =~ "<h1"
      assert view |> element("[data-role=chant-count]") |> render() =~ "104 recordings"

      assert has_element?(
               view,
               ~s([data-role=mass-tile][href="/chant/sections/mass_of_the_angels"])
             )

      doc = Floki.parse_document!(html)
      cards = Floki.find(doc, "[data-role=song-card]")
      assert length(cards) == length(Library.songs_to_mary(library))
      assert Floki.attribute(hd(cards), "data-chant-row") == ["salve_regina_simple"]

      assert has_element?(
               view,
               ~s([data-role=song-card] [data-play=salve_regina_simple][data-src^="https://s3."])
             )

      sections = Floki.find(doc, "[data-role=section-card]")
      assert length(sections) == 12

      assert has_element?(
               view,
               ~s([data-role=section-card][href="/chant/sections/ourLady"]),
               "Hymns to Our Lady"
             )

      assert length(Floki.find(doc, "[data-role=section-card] img")) == 12
    end

    test "leaves out what the site cannot keep: Learned, favourites, played lately, own sets",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chant")

      refute html =~ "Your favourites"
      refute html =~ "Played lately"
      refute html =~ "Make your own set"
    end

    test "the search rides in the link and finds by title, prayer and words", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chant")

      view |> form("#chant-search", %{"q" => "salve regina"}) |> render_change()
      assert_patch(view, "/chant?q=salve+regina")
      assert has_element?(view, "[data-role=results] [data-chant-row=salve_regina_simple]")

      {:ok, view, _html} = live(conn, "/chant?q=glory+be")
      assert has_element?(view, "[data-role=results] [data-chant-row=gloria_patri]")

      {:ok, view, _html} = live(conn, "/chant?q=no+chant+sings+this")
      assert has_element?(view, "[data-role=no-match]")
    end

    test "a q that is not text is no search, not a crash", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chant?q[x]=1")
      assert html =~ "Songs to Mary"
    end

    test "a search event that is not text is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chant")
      assert render_hook(view, "search", %{"q" => %{"x" => "1"}}) =~ "Songs to Mary"
    end

    test "the header links to Chant after Prayers", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chant")
      [header | _] = html |> Floki.parse_document!() |> Floki.find("header")
      hrefs = header |> Floki.find("a[data-nav-link]") |> Floki.attribute("href")
      prayers = Enum.find_index(hrefs, &(&1 == "/prayers"))
      assert Enum.at(hrefs, prayers + 1) == "/chant"
    end
  end

  describe "/chant/sections/:section_id" do
    test "a section's shelf: its painting, summary, Play all, the parts' strip, numbered rows",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/chant/sections/mass")

      assert view |> element("h1") |> render() =~ "The Ordinary of the Mass"
      assert view |> element("[data-role=summary]") |> render() =~ ~r/\d+ chants · \d+ min/
      assert has_element?(view, "[data-role=play-all]")
      assert has_element?(view, ~s([data-role=parts] a[href="#part-0"]), "Mass VIII, De Angelis")
      assert has_element?(view, "#part-1 [data-chant-row=kyrie_orbis_factor]")
      assert html =~ "chant-row__number"

      assert has_element?(
               view,
               ~s([data-chant-row=kyrie_de_angelis] a[href="/chant/kyrie_de_angelis"])
             )
    end

    test "a shelf of paintings of their own hangs one on each row", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chant/sections/ourLady")

      refute html =~ "chant-row__number"
      assert html =~ "chant-row__thumb"
      assert html =~ "Hymns to Our Lady"
    end

    test "the Mass of the Angels' shelf, its note said without its name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chant/sections/mass_of_the_angels")

      assert view |> element("h1") |> render() =~ "Mass of the Angels"

      assert view |> element("[data-role=section-note]") |> render() =~
               "For feasts, and any Sunday"

      assert view |> element("[data-role=chant-row]", "Kyrie") |> render() =~ "Lord, Have Mercy"
      refute has_element?(view, "[data-role=parts]")
      # The shelf already says Mass of the Angels, so no row repeats it.
      refute view |> element("[data-queue]") |> render() =~ "· Mass of the Angels"
    end

    test "an unknown section is a 404", %{conn: conn} do
      error =
        assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/chant/sections/nowhere") end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "/chant/:chant_id" do
    test "the chant's page: titles, detail, the recording, its lines and the prayer it sings",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/chant/salve_regina_simple")
      library = Library.load(nil)
      chant = Library.chant(library, "salve_regina_simple")

      assert view |> element("h1") |> render() =~ "Salve Regina"

      assert view |> element("[data-role=subtitle]") |> render() =~
               "Hail, Holy Queen · simple melody"

      # The title is the two names alone, as the app's; when it is sung is
      # said only for a chant with no timed lines, in the now line.
      refute has_element?(view, "[data-role=detail]")
      refute view |> element("article") |> render() =~ "Trinity Sunday to Advent"
      # The recording goes to the site's one chant player, with what its mini
      # player shows; the mini player stands aside on a chant's own page.
      assert has_element?(view, ~s([data-role=player][data-src="#{chant.audio.url}"]))
      [facts] = Floki.attribute(Floki.parse_document!(html), "[data-role=player]", "data-facts")

      assert %{"latin" => "Salve Regina", "href" => "/chant/salve_regina_simple"} =
               Jason.decode!(facts)

      assert has_element?(view, "#chant-view[data-hides-chant-player]")

      doc = Floki.parse_document!(html)
      lines = Floki.find(doc, "[data-role=line]")
      assert length(lines) == length(chant.lines)
      assert Floki.attribute(hd(lines), "data-start") == [to_string(hd(chant.lines).start)]
      assert html =~ "Line 1 of #{length(chant.lines)}"

      assert has_element?(view, ~s([data-role=chant-prayer][href="/prayers/hail_holy_queen"]))
      assert has_element?(view, "[data-role=also-sung] [data-chant-row=salve_regina_solemn]")
      assert has_element?(view, ~s([data-role=source][href="#{chant.source_url}"]))
      assert view |> element("[data-role=credit]") |> render() =~ "Verbum Gloriae"
    end

    test "the Words ride in the link; Both is the default and never written", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chant/salve_regina_simple")
      assert has_element?(view, ~s(#chant-view[data-words=both]))

      assert has_element?(
               view,
               ~s([data-role=words-choice] a[aria-current][href="/chant/salve_regina_simple"])
             )

      view |> element("[data-role=words-choice] a", "Latin") |> render_click()
      assert_patch(view, "/chant/salve_regina_simple?words=latin")
      assert has_element?(view, ~s(#chant-view[data-words=latin]))

      {:ok, view, _html} = live(conn, "/chant/salve_regina_simple?words[x]=1")
      assert has_element?(view, ~s(#chant-view[data-words=both]))
    end

    test "back and on wait for the chant to play; the error waits for a press", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chant/salve_regina_simple")

      assert has_element?(view, "[data-role=back-step][disabled]")
      assert has_element?(view, "[data-role=on-step][disabled]")
      refute has_element?(view, "[data-role=play][disabled]")
      assert has_element?(view, "[data-role=player] [data-role=error][hidden]")
    end

    test "a chant with no timed lines says when it is sung in its now line", %{conn: conn} do
      chant = Enum.find(Library.load(nil).chants, &(&1.lines == []))

      if chant do
        {:ok, view, _html} = live(conn, Library.chant_path(chant.id))
        assert view |> element("[data-now=latin]") |> render() =~ chant.detail
        refute has_element?(view, "[data-role=line-count]")
      end
    end

    test "the list pages carry a quiet line for a recording that will not play",
         %{conn: conn} do
      for path <- ["/chant", "/chant/sections/mass", "/chant/sets/benediction"] do
        {:ok, view, _html} = live(conn, path)
        assert has_element?(view, "[data-role=error][hidden]"), path
      end
    end

    test "The Sheet Music opens the full score over the page, in the link", %{conn: conn} do
      chant = Library.chant(Library.load(nil), "salve_regina_simple")
      {:ok, view, _html} = live(conn, "/chant/salve_regina_simple")
      refute has_element?(view, "[data-role=score]")

      view |> element("[data-role=score-open]") |> render_click()
      assert_patch(view, "/chant/salve_regina_simple?score=full")

      assert has_element?(
               view,
               ~s(#chant-score[role=dialog][aria-modal=true][phx-hook=ChantScore])
             )

      assert view |> element("#chant-score-heading") |> render() =~ "Salve Regina"
      assert view |> element("[data-role=score-done]") |> render() =~ "Done"

      # Every page of the score in order, each named, each from the site.
      drawings =
        view |> render() |> Floki.parse_document!() |> Floki.find("[data-role=score-drawing]")

      assert length(drawings) == length(chant.score)

      for {drawing, part} <- Enum.zip(drawings, chant.score) do
        [src] = Floki.attribute(drawing, "data-src")
        assert src == "/chant/scores/" <> Path.basename(part.url)
        assert Floki.attribute(drawing, "aria-label") == ["Sheet music: #{part.caption}"]
      end

      assert view |> element(".chant-score__caption", "Ora pro nobis") |> has_element?()

      # The small player drives the page's own recording; the zoom is a pair of buttons.
      assert has_element?(view, "#chant-score [data-act=toggle][aria-pressed=false]")
      assert has_element?(view, "#chant-score [data-role=score-scrub]")
      assert has_element?(view, ~s(#chant-score [data-zoom=in][aria-label="Zoom in"]))
      assert has_element?(view, ~s(#chant-score [data-zoom=out][aria-label="Zoom out"]))

      view |> element("[data-role=score-done]") |> render_click()
      assert_patch(view, "/chant/salve_regina_simple")
      refute has_element?(view, "[data-role=score]")
    end

    test "the full score keeps the Words, and opens from a link", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chant/salve_regina_simple?words=latin")

      assert has_element?(
               view,
               ~s([data-role=score-open][href="/chant/salve_regina_simple?words=latin&score=full"])
             )

      {:ok, view, _html} = live(conn, "/chant/salve_regina_simple?words=latin&score=full")
      assert has_element?(view, "[data-role=score]")

      assert has_element?(
               view,
               ~s([data-role=score-done][href="/chant/salve_regina_simple?words=latin"])
             )

      {:ok, view, _html} = live(conn, "/chant/salve_regina_simple?score=nonsense")
      refute has_element?(view, "[data-role=score]")
    end

    test "an unknown chant is a 404", %{conn: conn} do
      error = assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/chant/nowhere") end
      assert Plug.Exception.status(error) == 404
    end

    test "every chant's page opens", %{conn: conn} do
      for chant <- Library.load(nil).chants do
        assert {:ok, _view, _html} = live(conn, Library.chant_path(chant.id))
      end
    end
  end

  describe "the sitemap" do
    test "lists /chant, every section's shelf and every chant" do
      sitemap = File.read!(Application.app_dir(:lumen_viae, "priv/static/sitemap.xml"))
      library = Library.load(nil)

      assert sitemap =~ "<loc>https://www.lumenviae.org/chant</loc>"
      assert sitemap =~ "<loc>https://www.lumenviae.org/chant/sections/mass_of_the_angels</loc>"

      for group <- library.groups do
        assert sitemap =~ "<loc>https://www.lumenviae.org/chant/sections/#{group.id}</loc>"
      end

      for chant <- library.chants do
        assert sitemap =~ "<loc>https://www.lumenviae.org/chant/#{chant.id}</loc>"
      end
    end
  end
end
