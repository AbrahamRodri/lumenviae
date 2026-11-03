defmodule LumenViaeWeb.ChantScoreController do
  @moduledoc """
  `GET /chant/scores/:file`: a page of a chant's sheet music, the packed
  drawing the apps draw (`.lvscore`), for the full score on a chant's page
  (`LumenViaeWeb.Live.Chants.Chant`), whose `ChantScore` hook inflates and
  draws it.

  The page is the Chant Library's file in the public assets bucket, which
  sends no CORS headers, so the browser cannot read it there: the server
  fetches it (`LumenViae.Rosary.fetch_chant_score_page/1`, only a page the
  library names) and hands it on unchanged. The name carries the file's
  checksum, so the answer is cached for a year; a page the library does
  not name is a 404, and a bucket that does not answer a 502, cached
  nowhere.
  """
  use LumenViaeWeb, :controller

  alias LumenViae.Rosary

  def show(conn, %{"file" => file}) do
    case Rosary.fetch_chant_score_page(file) do
      {:ok, bytes} ->
        conn
        |> put_resp_content_type("application/octet-stream", nil)
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> put_resp_header("x-content-type-options", "nosniff")
        |> send_resp(200, bytes)

      {:error, :not_found} ->
        conn |> put_resp_content_type("text/plain") |> send_resp(404, "Not Found")

      {:error, _reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> put_resp_header("cache-control", "no-store")
        |> send_resp(502, "The sheet music could not be fetched")
    end
  end
end
