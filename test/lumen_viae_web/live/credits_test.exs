defmodule LumenViaeWeb.Live.CreditsTest do
  @moduledoc """
  `/credits`, Sources & Credits: the Prayer Book's chapters folding open
  with every prayer's origin, the paintings with their licences, the
  chants' and the books' sources, and the ways into it (the footer, and the
  Source line at the foot of a prayer's page). The data is the library in
  `priv/library/`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Credits.Sources
  alias LumenViaeWeb.Live.Prayers.Book

  defp page(conn, path), do: conn |> get(path) |> html_response(200) |> Floki.parse_document!()

  describe "/credits" do
    test "renders with its title, lede, contact and jump pills", %{conn: conn} do
      {:ok, view, html} = live(conn, "/credits")

      assert page_title(view) =~ "Sources"
      assert html =~ "wherever it is known"

      assert has_element?(
               view,
               ~s(a[data-role=contact][href="mailto:rodriguez.abrahamdev@gmail.com"])
             )

      for anchor <- ~w(#prayers #paintings #chant #books #licences) do
        assert has_element?(view, ~s(a[data-role=jump][href="#{anchor}"]))
      end

      assert has_element?(view, "[data-role=last-checked]", "Last checked 15 November 2026.")
    end

    test "one details per Prayer Book chapter, only the first open, every prayer once",
         %{conn: conn} do
      book = Book.load(nil, novenas: true)
      doc = page(conn, "/credits")
      details = Floki.find(doc, "#prayers details[data-role=chapter]")

      assert length(details) == length(Sources.prayer_chapters(book))

      assert [{"details", attrs, _}] =
               Floki.find(doc, "#prayers details[data-role=chapter][open]")

      assert {"id", "chapter-#{hd(Sources.prayer_chapters(book)).chapter.id}"} in attrs

      ids = doc |> Floki.find("#prayers li[id^=credit-]") |> Floki.attribute("id")
      assert length(ids) == Book.prayer_count(book)
      assert ids == Enum.uniq(ids)
    end

    test "a prayer links to its page with its origin beneath", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/credits")

      assert has_element?(view, ~s(#credit-memorare a[href="/prayers/memorare"]))

      assert view |> element("#credit-memorare [data-role=origin]") |> render() =~
               "Attributed to St Bernard of Clairvaux · 12th century"
    end

    test "a novena's painting with its credit and licence pill", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/credits")

      therese = view |> element("#painting-st_therese_novena") |> render()
      assert therese =~ "Józef Mehoffer"

      assert has_element?(
               view,
               ~s(#painting-st_therese_novena a[data-role=licence][href="https://creativecommons.org/licenses/by-sa/4.0/"]),
               "CC BY-SA 4.0"
             )

      assert has_element?(
               view,
               "#painting-undoer_of_knots_novena [data-role=licence]",
               "Public domain"
             )
    end

    test "the chants and the books carry their sources", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/credits")

      assert has_element?(view, "#chant", "Recordings and scores by Verbum Gloriae")
      assert has_element?(view, ~s(#chant a[href^="https://www.verbumgloriae.es/"]))

      assert has_element?(
               view,
               ~s(#book-story-of-a-soul a[href="https://www.gutenberg.org/ebooks/16772"])
             )

      assert has_element?(view, "#book-story-of-a-soul", "LibriVox volunteers, audiobook #8021")
      assert has_element?(view, "#book-true-devotion", "Faber")
    end
  end

  describe "the ways in" do
    test "the licences that ask for their notice carry it in full", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/credits")
      rows = view |> element("#licences") |> render()

      for id <- ~w(divinum-officium missale-meum phosphor cinzel eb-garamond) do
        assert has_element?(view, "#licence-#{id}")
      end

      assert rows =~ "Copyright (c) 2026 Divinum Officium"
      assert rows =~ "Copyright (c) 2022 Marcin Molenda"
      assert rows =~ "Permission is hereby granted, free of charge"
      assert rows =~ "Copyright 2020 The Cinzel Project Authors"
      assert rows =~ "SIL OPEN FONT LICENSE Version 1.1"
    end

    test "the footer links to the credits", %{conn: conn} do
      link = conn |> page("/") |> Floki.find(~s(footer a[href="/credits"]))

      assert link != []
      assert Floki.text(link) =~ "Credits"
    end

    test "a prayer's Source line links to the Prayer Book's credits", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/st_joseph_novena")

      assert has_element?(view, ~s([data-role=source] a[href="/credits#prayers"]), "Source")
    end
  end

  test "a painting's line ends at its source; the pill carries the licence" do
    alias LumenViaeWeb.Live.Credits.Sources

    assert Sources.credit_line(
             "Józef Mehoffer, St Therese of Lisieux, 1929, Mehoffer Museum, Krakow. Photo: Ablakok, via Wikimedia Commons, CC BY-SA 4.0 (creativecommons.org/licenses/by-sa/4.0), cropped."
           ) ==
             "Józef Mehoffer, St Therese of Lisieux, 1929, Mehoffer Museum, Krakow. Photo: Ablakok, via Wikimedia Commons, cropped."

    assert Sources.credit_line(
             "Giovanni Battista Tiepolo, The Immaculate Conception, 1767–69, Museo del Prado, Madrid. Public domain, via Wikimedia Commons."
           ) ==
             "Giovanni Battista Tiepolo, The Immaculate Conception, 1767–69, Museo del Prado, Madrid. Via Wikimedia Commons."

    assert Sources.credit_line(
             "Batoni, The Sacred Heart, 1767, Gesù, Rome. CC0, via Wikimedia Commons."
           ) ==
             "Batoni, The Sacred Heart, 1767, Gesù, Rome. Via Wikimedia Commons."

    assert Sources.credit_line(
             "A Redemptorist print, scan by LimosaCorel, via Wikimedia Commons. Public domain."
           ) ==
             "A Redemptorist print, scan by LimosaCorel, via Wikimedia Commons."
  end

  test "every painting the site hangs is credited, the Advent cards' two among them", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, "/credits")

    manifest =
      [:code.priv_dir(:lumen_viae), "static", "images", "paintings", "manifest.json"]
      |> Path.join()
      |> File.read!()
      |> Jason.decode!()

    rows = view |> element("#site-paintings") |> render()

    assert length(Floki.find(Floki.parse_fragment!(rows), "[data-role=site-painting]")) ==
             length(manifest["paintings"])

    assert rows =~ "The Prophet Isaiah (Sistine Chapel ceiling)"
    assert rows =~ "Michelangelo, 1508–12, Sistine Chapel, Vatican"
    assert rows =~ "Fra Angelico, 1425–26, Museo del Prado, Madrid"
  end
end
