defmodule LumenViaeWeb.Live.Chants.SetsTest do
  @moduledoc """
  The sung sets on the website: the tiles and the Sets of Chants shelf on
  `/chant`, Sets of Chants at `/chant/sets`, and a set's page at
  `/chant/sets/:occasion_id`. The sets are the library's `occasions` in
  `priv/library/chant_library.json`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Chants.Occasions

  @ids ~w(benediction visit sung_rosary before_bed before_work for_the_dead)

  describe "/chant" do
    test "the tiles place the sung sets around the Mass of the Angels, as the app's grid",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chant")

      hrefs =
        html
        |> Floki.parse_document!()
        |> Floki.find(".chant-tiles a")
        |> Floki.attribute("href")

      assert hrefs == [
               "/chant/sets/sung_rosary",
               "/chant/sets/benediction",
               "/chant/sections/mass_of_the_angels",
               "/chant/sets/before_bed"
             ]
    end

    test "the Sets of Chants shelf: six cards, each with its queue, disc and first chants",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/chant")
      doc = Floki.parse_document!(html)

      cards = Floki.find(doc, "[data-role=set-card]")
      assert Enum.flat_map(cards, &Floki.attribute(&1, "data-set")) == @ids
      assert has_element?(view, ~s([data-role=sets-link][href="/chant/sets"]))

      [rosary] = Floki.find(doc, ~s([data-role=set-card][data-set=sung_rosary]))
      [entries] = Floki.attribute(rosary, "data-entries")
      queue = Jason.decode!(entries)
      # The Creed's pendant, five decades of a Pater, ten Aves, a Gloria
      # and the Fatima prayer, the Salve and the Sign of the Cross.
      assert length(queue) == 2 + 5 + 5 * 13 + 2
      assert [["in_nomine_patris", "https://s3." <> _, 0] | _] = queue
      assert length(Floki.find(rosary, ".chant-set-card__list li")) == 4
      assert Floki.text(rosary) =~ "and 3 more"
      assert Floki.find(rosary, "[data-play-set]") != []
    end
  end

  describe "/chant/sets" do
    test "lists the six sets as wide cards, each opening its page", %{conn: conn} do
      {:ok, view, html} = live(conn, "/chant/sets")

      assert view |> element("h1") |> render() =~ "Sets of Chants"
      assert html =~ "Chants sung one after another, for a time of prayer."

      hrefs =
        html
        |> Floki.parse_document!()
        |> Floki.find("[data-role=wide-set-card]")
        |> Floki.attribute("href")

      assert hrefs == Enum.map(@ids, &"/chant/sets/#{&1}")

      assert view |> element(~s([href="/chant/sets/benediction"])) |> render() =~
               "Benediction: hymns before the Host"

      refute html =~ "Make your own set"
      refute html =~ "Your sets"
    end
  end

  describe "/chant/sets/:occasion_id" do
    test "a set's page: its head, Play all, Pause Between Chants and the order with its notes",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/chant/sets/sung_rosary")

      assert view |> element("h1") |> render() =~ "A Sung Rosary"
      assert view |> element("[data-role=summary]") |> render() =~ ~r/\d+ chants · \d+ min/
      assert has_element?(view, "[data-role=play-all][data-play-set]")
      assert has_element?(view, "[data-role=pauses-between] input[type=checkbox]")
      assert has_element?(view, ~s([data-role=set][data-set=sung_rosary][data-entries]))

      assert view |> element("[data-role=rubric]", "Five times") |> render() =~
               "Name each mystery"

      doc = Floki.parse_document!(html)
      rows = Floki.find(doc, "[data-role=set-row]")
      # Each step once, numbered in order.
      assert length(rows) == 2 + 3 + 4 + 2
      assert Enum.flat_map(rows, &Floki.attribute(&1, "data-origin")) == Enum.map(0..10, &"#{&1}")

      [aves] = Floki.find(doc, ~s([data-role=set-row][data-origin="6"]))
      assert Floki.text(Floki.find(aves, "[data-role=times]")) == "×10"
      assert Floki.attribute(aves, "button", "data-play-from") == ["6"]
      assert Floki.attribute(aves, "a", "href") == ["/chant/ave_maria"]
    end

    test "Before Bed sings tonight's song to Mary", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chant/sets/before_bed")
      library = Library.load(nil)
      tonight = Occasions.antiphon_of_the_season(library, Date.utc_today())

      assert html =~ "sub_tuum"
      assert html =~ ~s(href="/chant/#{tonight.id}")
    end

    test "a timezone the browser sends sets the day; one that is not is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chant/sets/before_bed")
      assert render_hook(view, "set_timezone", %{"offset" => 0}) =~ "Before Bed"
      assert render_hook(view, "set_timezone", %{"offset" => "nonsense"}) =~ "Before Bed"
      assert render_hook(view, "set_timezone", %{}) =~ "Before Bed"
    end

    test "leaves out what the site cannot keep: the bookmark, Share", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chant/sets/benediction")
      refute html =~ "Save as your own set"
      refute html =~ "Share"
    end

    test "every set's page opens", %{conn: conn} do
      for id <- @ids, do: assert({:ok, _view, _html} = live(conn, "/chant/sets/#{id}"))
    end

    test "an unknown set is a 404", %{conn: conn} do
      error = assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/chant/sets/nowhere") end
      assert Plug.Exception.status(error) == 404
    end
  end

  describe "the sitemap" do
    test "lists Sets of Chants and every set" do
      sitemap = File.read!(Application.app_dir(:lumen_viae, "priv/static/sitemap.xml"))
      assert sitemap =~ "<loc>https://www.lumenviae.org/chant/sets</loc>"

      for occasion <- Occasions.all(Library.load(nil)) do
        assert sitemap =~ "<loc>https://www.lumenviae.org/chant/sets/#{occasion.id}</loc>"
      end
    end
  end
end
