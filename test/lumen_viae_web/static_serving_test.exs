defmodule LumenViaeWeb.StaticServingTest do
  @moduledoc """
  How the endpoint serves static files and the LiveView socket, which decide
  what a returning visitor downloads again and what a page costs on the wire.
  """
  use LumenViaeWeb.ConnCase, async: true

  describe "images and fonts" do
    test "are cached for a week, so a returning visitor does not ask again", %{conn: conn} do
      conn = get(conn, "/images/ornate-blue-gold-bg-symbols.jpg")

      assert response(conn, 200)
      assert get_resp_header(conn, "cache-control") == ["public, max-age=604800"]
      assert [_etag] = get_resp_header(conn, "etag")
    end

    test "still answer a conditional request with a 304", %{conn: conn} do
      [etag] = conn |> get("/images/ornate-blue-gold-bg-symbols.jpg") |> get_resp_header("etag")

      conn =
        build_conn()
        |> put_req_header("if-none-match", etag)
        |> get("/images/ornate-blue-gold-bg-symbols.jpg")

      assert response(conn, 304)
    end

    test "a woodcut's WebP is served too", %{conn: conn} do
      conn = get(conn, "/images/woodcuts/annunciation-durer-640.webp")

      assert response(conn, 200)
      assert get_resp_header(conn, "cache-control") == ["public, max-age=604800"]
    end
  end

  describe "the files crawlers and browsers revalidate" do
    test "robots.txt and the sitemap are not cached for a week", %{conn: conn} do
      for path <- ["/robots.txt", "/sitemap.xml"] do
        conn = get(conn, path)

        assert response(conn, 200)
        assert get_resp_header(conn, "cache-control") == ["public"]
      end
    end
  end

  describe "the logo's icons" do
    test "every icon, the share image and the logo art are served" do
      for path <- ~w(/favicon.ico /favicon.svg /favicon-16.png /favicon-32.png /favicon-48.png
                     /apple-touch-icon.png /icon-192.png /icon-512.png /icon-maskable-512.png
                     /og-image.png /images/logo/lockup-horizontal-gold.svg
                     /images/logo/symbol-gold.svg /images/logo/symbol-compact-gold.svg) do
        assert build_conn() |> get(path) |> response(200), "#{path} is not served"
      end
    end

    test "the install manifest is served as a manifest and names the icons", %{conn: conn} do
      conn = get(conn, "/site.webmanifest")

      assert response(conn, 200)
      assert [type] = get_resp_header(conn, "content-type")
      assert type =~ "application/manifest+json"

      manifest = Jason.decode!(conn.resp_body)
      assert manifest["name"] == "Lumen Viae"
      assert manifest["short_name"] == "Lumen Viae"
      assert manifest["theme_color"] == "#0A0A15"
      assert manifest["background_color"] == "#0A0A15"
      assert manifest["display"] == "standalone"
      assert manifest["start_url"] == "/"

      assert Enum.map(manifest["icons"], &{&1["src"], &1["purpose"]}) == [
               {"/icon-192.png", nil},
               {"/icon-512.png", nil},
               {"/icon-maskable-512.png", "maskable"}
             ]
    end
  end

  describe "the LiveView socket" do
    test "negotiates per-message compression" do
      {"/live", Phoenix.LiveView.Socket, opts} =
        Enum.find(LumenViaeWeb.Endpoint.__sockets__(), &match?({"/live", _, _}, &1))

      assert opts[:websocket][:compress] == true
    end
  end
end
