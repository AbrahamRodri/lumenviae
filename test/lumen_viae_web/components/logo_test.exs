defmodule LumenViaeWeb.Components.LogoTest do
  @moduledoc """
  The logo on the public site and the console: the icon tags in `<head>`,
  the lockup in the header and the symbol in the footer.
  """
  use LumenViaeWeb.ConnCase, async: true

  defp doc(conn, path), do: conn |> get(path) |> html_response(200) |> Floki.parse_document!()

  # The value of `name` on the one element `selector` matches; fails when
  # there are none or several.
  defp attr(doc, selector, name) do
    assert [value] = Floki.attribute(doc, selector, name), "expected exactly one #{selector}"
    value
  end

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

  describe "the root layouts" do
    # In tests there is no digest manifest, so ~p renders the plain path and
    # the hrefs above would pass either way. In production ~p names the
    # digested file, which the top-level Plug.Static does not serve.
    test "name the top-level icons by plain path, not ~p" do
      for layout <- ~w(root.html.heex root_admin.html.heex) do
        source = File.read!(Path.join("lib/lumen_viae_web/components/layouts", layout))

        for file <- ~w(favicon.svg favicon.ico apple-touch-icon.png site.webmanifest) do
          refute source =~ ~s(~p"/#{file}"), "#{layout} names /#{file} through ~p"
        end
      end
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
