defmodule LumenViaeWeb.Components.LogoTest do
  @moduledoc """
  The logo on the public site and the console: the icon tags in `<head>`,
  the lockup in the header and the symbol in the footer.
  """
  use LumenViaeWeb.ConnCase, async: true

  defp doc(conn, path), do: conn |> get(path) |> html_response(200) |> Floki.parse_document!()

  defp attr(doc, selector, name), do: doc |> Floki.attribute(selector, name) |> List.first()

  describe "the public site's head" do
    test "names every icon, the manifest and the theme colour", %{conn: conn} do
      doc = doc(conn, "/")

      assert attr(doc, ~s(link[rel=icon][type="image/svg+xml"]), "href") == "/favicon.svg"
      assert attr(doc, ~s(link[rel=icon][sizes=any]), "href") == "/favicon.ico"
      assert attr(doc, ~s(link[rel=apple-touch-icon]), "href") == "/apple-touch-icon.png"
      assert attr(doc, ~s(link[rel=manifest]), "href") == "/site.webmanifest"
      assert attr(doc, ~s(meta[name=theme-color]), "content") == "#0A0A15"
    end
  end

  describe "the header" do
    test "shows the lockup in a link home named for screen readers", %{conn: conn} do
      [link] = conn |> doc("/") |> Floki.find(~s(#site-header a[aria-label="Lumen Viae, home"]))

      assert Floki.attribute(link, "img", "src") == ["/images/logo/lockup-horizontal-gold.svg"]
      assert Floki.attribute(link, "img", "alt") == [""]
    end
  end

  describe "the footer" do
    test "shows the symbol", %{conn: conn} do
      footer = conn |> doc("/") |> Floki.find("#site-footer")

      assert Floki.attribute(footer, "img", "src") == ["/images/logo/symbol-gold.svg"]
    end
  end

  describe "the console" do
    test "has the same icons", %{conn: conn} do
      doc = doc(conn, "/admin/login")

      assert attr(doc, ~s(link[rel=icon][type="image/svg+xml"]), "href") == "/favicon.svg"
      assert attr(doc, ~s(link[rel=icon][sizes=any]), "href") == "/favicon.ico"
      assert attr(doc, ~s(link[rel=apple-touch-icon]), "href") == "/apple-touch-icon.png"
    end
  end
end
