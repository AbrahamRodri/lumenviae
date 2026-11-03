defmodule LumenViaeWeb.Live.Chants.MiniPlayerTest do
  # The chant mini player at the foot of the site (ChantMiniPlayer, the
  # app's ChantMiniPlayer): drawn once in the public root layout beside the
  # site's one chant <audio>, hidden until a chant is in hand, and kept off
  # the pages the app keeps it off. The playing itself is the browser's
  # (chant_session.js), checked by scripts/e2e/smoke.cjs.
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Chants.Occasions

  describe "the root layout" do
    test "every public page carries the chant audio and the mini player, hidden", %{conn: conn} do
      for path <- ["/", "/prayers", "/chant", "/explore"] do
        doc = conn |> get(path) |> html_response(200) |> Floki.parse_document!()

        assert [_] = Floki.find(doc, "audio#site-chant-audio"), path
        [mini] = Floki.find(doc, "section#chant-mini[hidden]")
        assert Floki.attribute(mini, "aria-label") == ["Chant player"]

        assert Floki.attribute(mini, "[data-act=close]", "aria-label") == [
                 "Stop and close the player"
               ]

        assert Floki.find(mini, "[data-act=toggle][aria-pressed]") != []
        # The names open the chant's page by live navigation
        assert Floki.attribute(mini, "a[data-role=mini-open]", "data-phx-link") == ["redirect"]
      end
    end

    test "the chant audio is outside the LiveView, so it outlives a live navigation",
         %{conn: conn} do
      doc = conn |> get("/chant") |> html_response(200) |> Floki.parse_document!()
      assert Floki.find(doc, "[data-phx-main] #site-chant-audio") == []
      assert Floki.find(doc, "[data-phx-main] #chant-mini") == []
      # The chant pages no longer carry an <audio> of their own
      assert Floki.find(doc, "[data-phx-main] audio") == []
    end
  end

  describe "where it stands aside, as the app's showsChantPlayer" do
    test "a chant's page, a Rosary, an order prayed along, a Consecration day and the Act",
         %{conn: conn} do
      for path <- [
            "/chant/salve_regina_simple",
            "/mysteries/joyful/pray",
            "/prayers/orders/morning/pray",
            "/consecration/days/15",
            "/consecration/act"
          ] do
        {:ok, view, _html} = live(conn, path)
        assert has_element?(view, "[data-hides-chant-player]"), path
      end
    end

    test "every other page leaves it standing", %{conn: conn} do
      for path <- ["/", "/chant", "/chant/sets/benediction", "/prayers", "/consecration"] do
        {:ok, view, _html} = live(conn, path)
        refute has_element?(view, "[data-hides-chant-player]"), path
      end
    end
  end

  describe "what the pages hand the player" do
    test "a disc carries the chant's names, page and painting", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chant/sections/mass")
      doc = Floki.parse_document!(html)
      [disc | _] = Floki.find(doc, "[data-play]")
      [id] = Floki.attribute(disc, "data-play")
      [facts] = Floki.attribute(disc, "data-facts")
      chant = Library.chant(Library.load(nil), id)

      assert %{
               "latin" => latin,
               "english" => english,
               "href" => href,
               "thumb" => "/images/paintings/" <> _,
               "position" => _
             } = Jason.decode!(facts)

      assert {latin, english, href} ==
               {chant.latin_title, chant.english_title, Library.chant_path(id)}

      # Play all names its shelf, the mini player's "Kyrie · 3 of 12"
      assert [_] = Floki.find(doc, ~s([data-play-all][data-queue-id="section:mass"]))
      assert [_] = Floki.find(doc, "[data-play-all][data-queue-title]")
    end

    test "a sung set carries its title and the facts of every chant it sings", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chant/sets/visit")
      [set] = html |> Floki.parse_document!() |> Floki.find("[data-role=set]")
      assert Floki.attribute(set, "data-title") != [""]
      [entries] = Floki.attribute(set, "data-entries")
      [chants] = Floki.attribute(set, "data-chants")
      facts = Jason.decode!(chants)

      for [id, _src, _origin] <- Jason.decode!(entries) do
        assert %{"latin" => _, "href" => "/chant/" <> ^id} = facts[id]
      end
    end

    test "chants_json names each chant once, however often it is sung" do
      library = Library.load(nil)
      set = Occasions.unroll(Occasions.occasion(library, "sung_rosary"), library, ~D[2026-11-02])
      facts = Jason.decode!(Occasions.chants_json(set))
      ids = set.queue |> Enum.map(& &1.chant.id) |> Enum.uniq()
      assert Enum.sort(Map.keys(facts)) == Enum.sort(ids)
    end
  end
end
