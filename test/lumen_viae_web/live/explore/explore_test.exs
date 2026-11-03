defmodule LumenViaeWeb.Live.Explore.ExploreTest do
  @moduledoc """
  `/explore`: Explore's directory at rest, and the one search in `?q=`
  over the mysteries, the site's doors, the Prayer Book, the chants and
  the meditation sets. The mysteries are the app's
  (`LumenViae.Test.Mysteries`), so this module is `async: false`.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup do
    LumenViae.Test.Mysteries.seed_app_mysteries()
    :ok
  end

  describe "at rest" do
    test "is the site's directory, with the field and no results", %{conn: conn} do
      {:ok, view, html} = live(conn, "/explore")
      doc = Floki.parse_document!(html)

      assert doc |> Floki.find("h1") |> Floki.text() |> String.trim() == "Explore"
      assert has_element?(view, "#explore-search input[name=q]")
      refute has_element?(view, "[data-role=results]")

      for slug <- ~w(joyful sorrowful glorious luminous seven_sorrows) do
        assert has_element?(view, ~s([data-role=devotion][href="/mysteries/#{slug}"]))
      end

      assert length(Floki.find(doc, "[data-role=occasion]")) == 8
      assert has_element?(view, ~s([data-role=occasion][href="/prayers/orders/before_mass"]))
      assert has_element?(view, ~s(a[href="/prayers"]), "All prayers")
      assert has_element?(view, ~s([data-role=tile][href="/chant/sets"]))
      assert has_element?(view, ~s([data-role=tile][href="/hours"]))
      assert has_element?(view, ~s([data-role=book][href="/true-devotion"]))
      refute html =~ "Daily Missal"
    end

    test "carries its own title and a canonical address with no query", %{conn: conn} do
      html = conn |> get("/explore?q=salve") |> html_response(200)
      doc = Floki.parse_document!(html)

      assert doc |> Floki.find("title") |> Floki.text() =~ "Explore"

      assert [href] = doc |> Floki.find(~s(link[rel="canonical"])) |> Floki.attribute("href")
      assert String.ends_with?(href, "/explore")
    end

    test "the header links Explore after Hours and marks it here", %{conn: conn} do
      html = conn |> get("/explore") |> html_response(200)
      doc = Floki.parse_document!(html)

      labels =
        doc
        |> Floki.find("#site-header nav[aria-label=Main] > a")
        |> Enum.map(&(&1 |> Floki.text() |> String.trim()))

      assert Enum.drop_while(labels, &(&1 != "Hours")) |> Enum.take(2) == ["Hours", "Explore"]
      assert [_desktop, _phone] = Floki.find(doc, ~s(a[href="/explore"][aria-current=page]))
    end
  end

  describe "the search" do
    test "finds a mystery and opens its devotion's page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/explore?q=annunciation")

      assert view |> element("[data-role=best]") |> render() =~ "The Annunciation"
      assert has_element?(view, ~s([data-role=best] a[href="/mysteries/joyful"]))
      assert has_element?(view, ~s([data-role=chip][href="#explore-mysteries"]), "Mysteries")
    end

    test "finds a prayer and a chant by their Latin, accents and case aside", %{conn: conn} do
      for query <- ["Pater", "PÂTER"] do
        {:ok, view, _html} = live(conn, "/explore?" <> URI.encode_query(q: query))

        assert has_element?(view, ~s(#explore-results a[href="/prayers/our_father"]))
        assert has_element?(view, ~s(#explore-results a[href="/chant/pater_noster"]))
      end

      {:ok, view, _html} = live(conn, "/explore?q=ave+maria")
      assert has_element?(view, ~s(#explore-results a[href="/prayers/hail_mary"]))
      assert has_element?(view, ~s(#explore-results a[href="/chant/ave_maria"]))
    end

    test "Salve finds the Salve Regina in Prayers and Chants, the sections in Explore's order",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/explore?q=Salve")

      assert has_element?(view, ~s(#explore-results a[href="/chant/salve_regina_simple"]))
      assert has_element?(view, ~s(#explore-results a[href="/prayers/hail_holy_queen"]))

      kinds =
        html
        |> Floki.parse_document!()
        |> Floki.find("[data-role=section]")
        |> Floki.attribute("data-kind")

      assert kinds == ["prayers", "chants"]
    end

    test "an order of prayer as the best match offers Pray", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/explore?q=before+mass")

      assert has_element?(view, ~s([data-role=best][data-kind=prayers]))

      assert has_element?(
               view,
               ~s([data-role=best-pray][href="/prayers/orders/before_mass/pray"])
             )
    end

    test "a chant as the best match offers Listen, its recording on the button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/explore?q=pange+lingua")

      assert has_element?(view, ~s([data-role=best][data-chant-row="pange_lingua"]))

      assert view |> element("[data-role=best-listen]") |> render() =~
               ~s(data-play="pange_lingua")
    end

    test "a door found by name opens its page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/explore?q=hours+of+prayer")

      assert has_element?(view, ~s([data-role=best] a[href="/hours"]))
    end

    test "finds a meditation set by name and opens its prayer page", %{conn: conn} do
      {:ok, set} =
        Rosary.create_meditation_set(%{name: "Quietude of Nazareth", category: "joyful"},
          actor: LumenViae.Test.Admins.admin()
        )

      LumenViae.Test.Sets.with_meditation(set)

      {:ok, view, _html} = live(conn, "/explore?q=quietude")

      assert has_element?(view, ~s([data-role=best] a[href="/meditation-sets/#{set.id}/pray"]))
      assert view |> element("[data-role=best]") |> render() =~ "Joyful Mysteries"
    end

    test "says how many more past twelve rows", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/explore?q=lord")

      assert view |> element("[data-kind=prayers] [data-role=more]") |> render() =~
               ~r/And \d+ more\. Add a word to narrow the search\./
    end

    test "nothing found says so, and what to try", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/explore?q=zzqxv")

      assert view |> element("[data-role=no-match]") |> render() =~ "Nothing found"
      refute has_element?(view, "[data-role=chips]")
      assert view |> element("[data-role=announcement]") |> render() =~ "Nothing found"
    end

    test "typing patches the link, and clearing it goes back to the directory", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/explore")

      view |> form("#explore-search", %{"q" => "memorare"}) |> render_change()
      assert_patch(view, "/explore?q=memorare")
      assert has_element?(view, ~s(#explore-results a[href="/prayers/memorare"]))

      view |> element("[data-role=clear]") |> render_click()
      assert_patch(view, "/explore")
      assert has_element?(view, "[data-role=browse]")
    end

    test "a q that is not text is no search, not a crash", %{conn: conn} do
      {:ok, view, html} = live(conn, "/explore?q[x]=1")

      assert html =~ ~s(data-role="browse")
      assert render_hook(view, "search", %{"q" => %{"x" => "1"}}) =~ ~s(data-role="browse")
      assert render_hook(view, "set_timezone", %{"offset" => "nonsense"}) =~ "Explore"
      assert render_hook(view, "set_timezone", %{"offset" => 300}) =~ "Explore"
    end
  end

  describe "the sitemap" do
    test "lists /explore and no search" do
      sitemap = File.read!(Application.app_dir(:lumen_viae, "priv/static/sitemap.xml"))

      assert sitemap =~ "<loc>https://www.lumenviae.org/explore</loc>"
      refute sitemap =~ "/explore?"
    end
  end
end
