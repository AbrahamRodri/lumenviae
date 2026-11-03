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

    test "the chant audio names the one other origin its recordings come from", %{conn: conn} do
      doc = conn |> get("/chant") |> html_response(200) |> Floki.parse_document!()
      [origin] = Floki.attribute(doc, "audio#site-chant-audio", "data-origin")
      assert origin == "https://s3.us-east-2.amazonaws.com"
      assert String.starts_with?(LumenViae.Rosary.Library.chant_asset_base(), origin <> "/")
    end

    test "the admin console has neither the chant audio nor the mini player", %{conn: conn} do
      doc =
        conn
        |> log_in_admin()
        |> get("/admin")
        |> html_response(200)
        |> Floki.parse_document!()

      assert Floki.find(doc, "#site-chant-audio") == []
      assert Floki.find(doc, "#chant-mini") == []
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

    test "a Spiritual Reading chapter", %{conn: conn} do
      # The mark stands on the page's frame, whatever the book's text does
      {:ok, view, _html} = live(conn, "/spiritual-reading/imitation-of-christ/1")
      assert has_element?(view, "#spiritual-reading-chapter[data-hides-chant-player]")
    end

    test "today's Consecration day under a plan shows it, as the tab's root; its flow does not",
         %{conn: conn} do
      today = Date.utc_today()
      start = Date.add(today, -14)

      state = %{
        "plan" => %{"start" => Date.to_iso8601(start)},
        "done" => [],
        "intro_seen" => true,
        "today" => Date.to_iso8601(today)
      }

      {:ok, view, _html} = live(conn, "/consecration/days/15")
      render_hook(view, "consecration_state", state)
      refute has_element?(view, "[data-hides-chant-player]")

      # Another day of the same plan, and today's day walked, stand aside
      {:ok, view, _html} = live(conn, "/consecration/days/14")
      render_hook(view, "consecration_state", state)
      assert has_element?(view, "[data-hides-chant-player]")

      {:ok, view, _html} = live(conn, "/consecration/days/15?step=1")
      render_hook(view, "consecration_state", state)
      assert has_element?(view, "[data-hides-chant-player]")
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

    test "a set card on the Chant page carries its title and its chants' facts", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/chant")
      cards = html |> Floki.parse_document!() |> Floki.find("[data-role=set-card]")
      assert cards != []

      for card <- cards do
        assert [title] = Floki.attribute(card, "data-title")
        assert title != ""
        [entries] = Floki.attribute(card, "data-entries")
        facts = card |> Floki.attribute("data-chants") |> hd() |> Jason.decode!()

        for [id, _src, _origin] <- Jason.decode!(entries) do
          assert %{"latin" => _, "english" => _, "href" => "/chant/" <> ^id} = facts[id]
        end
      end
    end

    test "Explore's chant result hands the player its facts", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/explore?q=Salve")
      doc = Floki.parse_document!(html)
      discs = Floki.find(doc, "#explore-results [data-play][data-facts]")
      assert discs != []

      for disc <- discs do
        [id] = Floki.attribute(disc, "data-play")
        [facts] = Floki.attribute(disc, "data-facts")

        assert %{"latin" => _, "href" => "/chant/" <> ^id, "thumb" => "/images/" <> _} =
                 Jason.decode!(facts)
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
