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
    test "presents the app with one h1 and its features in order", %{conn: conn} do
      {:ok, view, html} = live(conn, "/app")
      doc = Floki.parse_document!(html)

      assert page_title(view) =~ "Lumen Viae for iPhone"
      assert doc |> Floki.find("h1") |> length() == 1

      for feature <- [
            "Your Rosary Today",
            "The Scriptural Rosary",
            "Hours of Prayer and Today&#39;s Mass",
            "The Chant Library",
            "Prayers",
            "Consecration to Mary",
            "Without a connection"
          ] do
        assert html =~ feature
      end
    end

    test "every download button goes to the App Store listing", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/app")

      links =
        html |> Floki.parse_document!() |> Floki.find(~s(a[href^="https://apps.apple.com"]))

      assert length(links) >= 2
      assert Enum.all?(links, &(Floki.attribute(&1, "href") == [@app_store]))
    end

    test "every screenshot has alt text, a size and its files", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/app")
      doc = Floki.parse_document!(html)
      images = Floki.find(doc, "main img, #app-page img")

      assert length(images) >= 10

      for img <- images do
        [src] = Floki.attribute(img, "src")
        [alt] = Floki.attribute(img, "alt")

        assert String.length(alt) > 20, "#{src} has no description"
        assert Floki.attribute(img, "width") == ["390"]
        assert Floki.attribute(img, "height") == ["848"]

        name = src |> Path.basename(".jpg")
        assert File.exists?(Path.join(@images, "#{name}.jpg"))
        assert File.exists?(Path.join(@images, "#{name}-390.webp"))
        assert File.exists?(Path.join(@images, "#{name}-780.webp"))
      end
    end

    test "previews with a screenshot image that exists", %{conn: conn} do
      html = conn |> get("/app") |> html_response(200)

      [image] =
        html
        |> Floki.parse_document!()
        |> Floki.find(~s(meta[property="og:image"]))
        |> Floki.attribute("content")

      assert image =~ "/images/app/og-app.jpg"
      assert File.exists?(Path.join(@images, "og-app.jpg"))
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
