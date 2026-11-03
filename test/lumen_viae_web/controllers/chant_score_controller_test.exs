defmodule LumenViaeWeb.ChantScoreControllerTest do
  @moduledoc """
  `GET /chant/scores/:file`: a score page the Chant Library names, fetched
  from the assets bucket (which Req.Test answers here) and handed on
  unchanged with a year's cache; anything else a 404, and a bucket that
  fails or sends another file a 502.
  """
  use LumenViaeWeb.ConnCase, async: true

  @name "chant-vers-alt-ora-pro-nobis-26838831a84d.lvscore"
  @fixture Path.expand("../../support/fixtures/chant_scores/#{@name}", __DIR__)

  defp stub(fun), do: Req.Test.stub(LumenViae.Rosary.ChantScore, fun)

  test "a page the library names is the bucket's file, cached for a year", %{conn: conn} do
    bytes = File.read!(@fixture)

    stub(fn req ->
      assert req.host == "s3.us-east-2.amazonaws.com"
      assert req.request_path == "/lumenviae-images/chants/scores/#{@name}"
      Plug.Conn.send_resp(req, 200, bytes)
    end)

    conn = get(conn, "/chant/scores/#{@name}")

    assert response(conn, 200) == bytes
    assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    assert [type] = get_resp_header(conn, "content-type")
    assert type =~ "application/octet-stream"
  end

  test "a name the library does not have is a 404 and asks the bucket nothing", %{conn: conn} do
    stub(fn _req -> flunk("the bucket was asked") end)

    for name <- [
          "chant-nowhere-000000000000.lvscore",
          "..%2F..%2Fsecrets",
          "chant-salve-regina-simple.lvscore"
        ] do
      assert conn |> get("/chant/scores/#{name}") |> response(404)
    end
  end

  test "a file that is not the library's, or a bucket that fails, is a 502 cached nowhere",
       %{conn: conn} do
    stub(fn req -> Plug.Conn.send_resp(req, 200, "not the score") end)
    conn1 = get(conn, "/chant/scores/#{@name}")
    assert response(conn1, 502)
    assert get_resp_header(conn1, "cache-control") == ["no-store"]

    stub(&Req.Test.transport_error(&1, :econnrefused))
    assert conn |> get("/chant/scores/#{@name}") |> response(502)

    stub(fn req -> Plug.Conn.send_resp(req, 403, "") end)
    assert conn |> get("/chant/scores/#{@name}") |> response(502)
  end
end
