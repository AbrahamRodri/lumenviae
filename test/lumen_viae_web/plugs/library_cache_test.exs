defmodule LumenViaeWeb.Plugs.LibraryCacheTest do
  @moduledoc """
  `LumenViaeWeb.Plugs.LibraryCache`: the library documents may be held by
  Cloudflare's edge, with an ETag and 304, only when
  `LIBRARY_EDGE_CACHE_SECONDS` is set. Unset, nothing changes.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViaeWeb.JsonApiHelpers
  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViaeWeb.Plugs.LibraryCache

  @shared "public, max-age=0, must-revalidate, s-maxage=600"

  test "covers each of the seven library documents" do
    assert length(LibraryCache.paths()) == length(LumenViae.Rosary.Library.documents())
    assert ["api", "v2", "prayer-book"] in LibraryCache.paths()
    assert ["api", "v2", "spiritual-reading"] in LibraryCache.paths()
  end

  describe "unset, as by default" do
    setup do
      put_env(:lumen_viae, :library_edge_cache_seconds, nil)
      :ok
    end

    test "a library document stays private, with no ETag", %{conn: conn} do
      conn = get_v2(conn, "/prayer-book")

      assert conn.status == 200
      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
      assert get_resp_header(conn, "etag") == []
    end
  end

  describe "set" do
    setup do
      put_env(:lumen_viae, :library_edge_cache_seconds, 600)
      :ok
    end

    test "a library document is shareable at the edge and carries a strong ETag", %{conn: conn} do
      for path <- LibraryCache.paths() do
        conn = get(conn, "/" <> Enum.join(path, "/"))

        assert conn.status == 200, inspect(path)
        assert get_resp_header(conn, "cache-control") == [@shared]
        assert [etag] = get_resp_header(conn, "etag")
        assert etag =~ ~r/\A"[0-9a-f]{64}"\z/
      end
    end

    test "the ETag is the same on every request, and differs with the fields asked for", %{
      conn: conn
    } do
      etag = fn path -> conn |> get_v2(path) |> get_resp_header("etag") end

      assert etag.("/prayer-book") == etag.("/prayer-book")
      refute etag.("/prayer-book") == etag.("/prayer-book?fields[prayer_book]=version,prayers")
    end

    test "a matching If-None-Match gets 304 with no body", %{conn: conn} do
      [etag] = conn |> get_v2("/consecration") |> get_resp_header("etag")

      revalidated =
        build_conn()
        |> put_req_header("if-none-match", ~s("other", #{etag}))
        |> get_v2("/consecration")

      assert revalidated.status == 304
      assert revalidated.resp_body == ""
      assert get_resp_header(revalidated, "etag") == [etag]
    end

    test "a weak copy of the ETag, as Cloudflare sends after compressing, also gets 304", %{
      conn: conn
    } do
      [etag] = conn |> get_v2("/consecration") |> get_resp_header("etag")

      for tag <- ["W/" <> etag, "*"] do
        revalidated =
          build_conn()
          |> put_req_header("if-none-match", tag)
          |> get_v2("/consecration")

        assert revalidated.status == 304, tag
      end
    end

    test "a stale If-None-Match gets the document", %{conn: conn} do
      conn =
        conn
        |> put_req_header("if-none-match", ~s("0000"))
        |> get_v2("/consecration")

      assert conn.status == 200
      assert conn.resp_body != ""
    end

    test "every other v2 route stays private, with no ETag", %{conn: conn} do
      conn = get_v2(conn, "/mysteries")

      assert conn.status == 200
      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
      assert get_resp_header(conn, "etag") == []
    end
  end
end
