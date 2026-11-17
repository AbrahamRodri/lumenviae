defmodule LumenViaeWeb.Live.Home.AppTest do
  @moduledoc """
  The iPhone app's landing page (/app): what it shows, that every download
  button leads to the App Store listing, that each screenshot it names
  exists, and that the header and footer lead to it.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @app_store "https://apps.apple.com/us/app/lumen-viae-rosary-meditations/id6760320749"
  @images Path.expand("../../../../priv/static/images/app", __DIR__)

  describe "the app page" do
    test "presents the app with one h1, the library's true counts and the six tiles", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, "/app")
      doc = Floki.parse_document!(html)

      assert page_title(view) =~ "Lumen Viae for iPhone"
      assert doc |> Floki.find("h1") |> length() == 1

      chants = length(LumenViae.Rosary.get_chant_library!(load: [:chants]).chants)
      prayers = length(LumenViae.Rosary.get_prayer_book!(load: [:prayers]).prayers)
      proof = doc |> Floki.find("[data-role=proof]") |> Floki.text()
      assert proof =~ "#{chants} chants"
      assert proof =~ "#{prayers} prayers"

      for tile <- [
            "Hours of Prayer",
            "Today&#39;s Mass",
            "Novenas",
            "Consecration",
            "Offline, no account",
            "The prayer book"
          ] do
        assert html =~ tile
      end

      assert html =~ "#{prayers} prayers, from the Angelus to the Litany of Loreto."
      refute html =~ ~s(name="robots")
    end

    test "plain /app is English, to the browser too", %{conn: conn} do
      html = conn |> get("/app") |> html_response(200)
      assert html =~ ~s(<html lang="en">)
      assert html =~ ~s(data-html-lang="en")
    end

    test "?lang=es is the page in Spanish, kept out of search engines", %{conn: conn} do
      html = conn |> get("/app?lang=es") |> html_response(200)
      assert html =~ ~s(<html lang="es">)
      assert html =~ ~s(data-html-lang="es")
      # The clip button is a mark only; its name is for screen readers.
      assert html =~ ~s(aria-label="Pausar")
      refute html =~ ~r/>\s*(Reproducir|Pausar)\s*</
      doc = Floki.parse_document!(html)

      assert doc |> Floki.find("h1") |> Floki.text() =~ "El Rosario, rezado dondequiera que estés"

      assert doc |> Floki.find(~s(meta[name="robots"])) |> Floki.attribute("content") == [
               "noindex"
             ]

      assert html =~ "Ciento cuatro cantos" or html =~ "cantos, para oír y aprender"
      assert html =~ "en latín e inglés"
    end

    test "the counts are spelled as words where a heading says them" do
      alias LumenViaeWeb.Live.Home.App.Words

      assert Words.spell_en(104) == "a hundred and four"
      assert Words.spell_en(250) == "two hundred and fifty"
      assert Words.spell_en(21) == "twenty-one"
      assert Words.spell_es(104) == "ciento cuatro"
      assert Words.spell_es(100) == "cien"
      assert Words.spell_es(235) == "doscientos treinta y cinco"
    end

    test "every download button goes to the App Store listing", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/app")

      links =
        html |> Floki.parse_document!() |> Floki.find(~s(a[href^="https://apps.apple.com"]))

      assert length(links) >= 2
      assert Enum.all?(links, &(Floki.attribute(&1, "href") == [@app_store]))
    end

    test "each download link is Apple's own badge, kept as downloaded", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/app")
      doc = Floki.parse_document!(html)
      badges = Floki.find(doc, ~s(a[href="#{@app_store}"] img))

      assert length(badges) >= 2

      for badge <- badges do
        assert Floki.attribute(badge, "alt") == ["Download on the App Store"]
        assert [src] = Floki.attribute(badge, "src")
        assert src =~ "/images/app/app-store-badge"
      end

      assert File.read!("priv/static/images/app/app-store-badge.svg") =~
               "Download_on_the_App_Store_Badge_US-UK_RGB_blk"
    end

    test "the Spanish page's badge is Apple's own, in Spanish", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/app?lang=es")
      badges = html |> Floki.parse_document!() |> Floki.find(~s(a[href="#{@app_store}"] img))

      assert length(badges) >= 2

      for badge <- badges do
        assert Floki.attribute(badge, "alt") == ["Descárgalo en el App Store"]
        assert Floki.attribute(badge, "src") == ["/images/app/app-store-badge-es.svg"]
      end

      assert File.read!("priv/static/images/app/app-store-badge-es.svg") =~
               "Download_on_the_App_Store_Badge_ESMX_RGB_blk"
    end

    # Each phone is its clip once recorded, else its still; either way it
    # says what it shows and its files exist.
    test "every phone says what it shows, and its files exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/app")
      phones = html |> Floki.parse_document!() |> Floki.find(".app-phone")

      assert length(phones) == 5

      for phone <- phones do
        case Floki.find(phone, "video") do
          [video] ->
            [label] = Floki.attribute(video, "aria-label")
            assert String.length(label) > 20
            assert video |> Floki.attribute("muted") != []
            [src] = phone |> Floki.find("source") |> Floki.attribute("src")
            assert File.exists?(Path.join("priv/static", src))

          [] ->
            [img] = Floki.find(phone, "img")
            [alt] = Floki.attribute(img, "alt")
            [src] = Floki.attribute(img, "src")
            assert String.length(alt) > 20
            assert File.exists?(Path.join("priv/static", src))
        end
      end
    end

    test "previews with a screenshot image that exists", %{conn: conn} do
      html = conn |> get("/app") |> html_response(200)

      [image] =
        html
        |> Floki.parse_document!()
        |> Floki.find(~s(meta[property="og:image"]))
        |> Floki.attribute("content")

      assert image =~ "/images/app/og-app-midnight.jpg"
      assert File.exists?(Path.join(@images, "og-app-midnight.jpg"))
    end
  end

  describe "the site's links" do
    # The header and footer are in the root layout, outside the LiveView,
    # so they are read from the full page the server sends.
    test "the header and footer lead to the app page", %{conn: conn} do
      doc = conn |> get("/") |> html_response(200) |> Floki.parse_document!()

      for selector <- ["#site-footer", "#site-header nav[aria-label=Main]"] do
        link = doc |> Floki.find(selector) |> Floki.find(~s(a[href="/app"]))

        assert link != [], "#{selector} has no link to /app"
        assert Floki.text(link) =~ "The App"
      end
    end
  end
end
