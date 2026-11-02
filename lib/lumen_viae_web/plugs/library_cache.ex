defmodule LumenViaeWeb.Plugs.LibraryCache do
  @moduledoc """
  Lets a shared cache (Cloudflare's edge) hold the seven library documents
  under `/api/v2` (`LumenViae.Rosary.Library.documents/0`), and lets a
  client revalidate one cheaply. Off unless `LIBRARY_EDGE_CACHE_SECONDS` is
  set, so by default every `/api/v2` response stays `private, no-store`.

  With it set, a successful GET of a library document carries:

    * `cache-control: public, max-age=0, must-revalidate, s-maxage=<n>`:
      the edge keeps it for `n` seconds, while a device or browser asks
      again every time, so an app's "is my copy current" check is never
      answered from its own stale copy;
    * a strong `etag`, the SHA-256 of the body, and `304 Not Modified`
      with no body when the request's `If-None-Match` names it.

  The library documents hold only public words and public, content-addressed
  file URLs, never a presigned link, which is why they alone may be shared.
  Every other `/api/v2` route keeps `private, no-store`.
  """
  @behaviour Plug

  import Plug.Conn

  alias LumenViae.Rosary.Library

  @paths Enum.map(
           Library.documents(),
           &["api", "v2", &1 |> to_string() |> String.replace("_", "-")]
         )

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{method: method, path_info: path} = conn, _opts)
      when method in ["GET", "HEAD"] and path in @paths do
    case Application.get_env(:lumen_viae, :library_edge_cache_seconds) do
      seconds when is_integer(seconds) and seconds > 0 ->
        register_before_send(conn, &shareable(&1, seconds))

      _off ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  @doc "The library documents' paths, as `path_info` lists."
  def paths, do: @paths

  defp shareable(%Plug.Conn{status: 200} = conn, seconds) do
    etag = ~s("#{:crypto.hash(:sha256, conn.resp_body) |> Base.encode16(case: :lower)}")

    conn =
      conn
      |> put_resp_header(
        "cache-control",
        "public, max-age=0, must-revalidate, s-maxage=#{seconds}"
      )
      |> put_resp_header("etag", etag)

    if etag in if_none_match(conn),
      do: %{conn | status: 304, resp_body: ""},
      else: conn
  end

  defp shareable(conn, _seconds), do: conn

  defp if_none_match(conn) do
    conn
    |> get_req_header("if-none-match")
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&String.trim/1)
  end
end
