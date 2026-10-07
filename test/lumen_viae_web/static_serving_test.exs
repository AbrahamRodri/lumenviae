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

  describe "the LiveView socket" do
    test "negotiates per-message compression" do
      {"/live", Phoenix.LiveView.Socket, opts} =
        Enum.find(LumenViaeWeb.Endpoint.__sockets__(), &match?({"/live", _, _}, &1))

      assert opts[:websocket][:compress] == true
    end
  end
end
