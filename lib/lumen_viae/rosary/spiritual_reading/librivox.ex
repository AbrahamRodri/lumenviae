defmodule LumenViae.Rosary.SpiritualReading.LibriVox do
  @moduledoc """
  HTTP client for LibriVox's catalogue API, the track list of a Spiritual
  Reading book's recording: `https://librivox.org/api/feed/audiobooks/?id=<id>&extended=1&format=json`,
  the address the apps fetch. The website's server fetches it, so a
  visitor's browser never calls LibriVox for it;
  `LumenViae.Rosary.SpiritualReading.Recording` reads and holds what comes
  back. The recordings themselves are on the Internet Archive and stream in
  the visitor's browser, as in the apps.

  Built as `LumenViae.Office.MissaleMeum` is: Req with no retries, 5
  seconds to connect and 15 to answer, the same well-behaved-bot
  User-Agent, no redirect followed (one is an answer that is not the
  track list), no compression asked for, the body read at most to 1 MB
  and stopped there (a book's whole feed is under 25 kB), and
  `:req_options` as the test seam (the suite injects
  `plug: {Req.Test, LumenViae.Rosary.SpiritualReading.LibriVox}`, so a test
  never touches the network). The overall deadline is the caller's.

      config :lumen_viae, :librivox,
        base_url: "https://librivox.org",
        req_options: []

  Answers `{:ok, json}`, `{:error, {:upstream_status, status}}`,
  `{:error, :too_large}`, `{:error, :undecodable}` or
  `{:error, :upstream_unreachable}`.
  """

  require Logger

  @user_agent "Mozilla/5.0 (compatible; LumenViae/1.0; +https://www.lumenviae.org)"

  @receive_timeout_ms 15_000
  @connect_timeout_ms 5_000
  @max_body_bytes 1_000_000

  @doc "The catalogue entry, with its tracks, of LibriVox audiobook `id`."
  def fetch_audiobook(id) when is_integer(id) and id > 0 do
    get("/api/feed/audiobooks/", id: id, extended: 1, format: "json")
  end

  @doc false
  def max_body_bytes, do: @max_body_bytes

  defp get(path, params) do
    options =
      [
        params: params,
        headers: [user_agent: @user_agent],
        receive_timeout: @receive_timeout_ms,
        connect_options: [timeout: @connect_timeout_ms],
        retry: false,
        redirect: false,
        compressed: false,
        # Decoded here, so a body that is not JSON is said as such.
        decode_body: false,
        into: &capped/2
      ]
      |> Keyword.merge(config(:req_options, []))

    case Req.get(config(:base_url, "https://librivox.org") <> path, options) do
      {:ok, %Req.Response{status: 200} = response} ->
        if Req.Response.get_private(response, :too_large) do
          Logger.warning("LibriVox's answer for #{path} passed #{@max_body_bytes} bytes")
          {:error, :too_large}
        else
          decode(response.body, path)
        end

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("LibriVox answered #{status} for #{path}")
        {:error, {:upstream_status, status}}

      {:error, exception} ->
        Logger.warning("LibriVox unreachable: #{Exception.message(exception)}")
        {:error, :upstream_unreachable}
    end
  rescue
    exception ->
      Logger.warning("LibriVox request raised: #{Exception.message(exception)}")
      {:error, :upstream_unreachable}
  end

  # The body gathered a chunk at a time, and dropped the moment it passes
  # the cap (or the server says in advance that it will).
  defp capped({:data, data}, {request, response}) do
    body = response.body <> data

    if byte_size(body) > @max_body_bytes or declared_too_large?(response) do
      {:halt, {request, %{Req.Response.put_private(response, :too_large, true) | body: ""}}}
    else
      {:cont, {request, %{response | body: body}}}
    end
  end

  defp declared_too_large?(response) do
    case Req.Response.get_header(response, "content-length") do
      [length | _rest] -> match?({n, ""} when n > @max_body_bytes, Integer.parse(length))
      [] -> false
    end
  end

  defp decode(body, path) do
    case Jason.decode(body) do
      {:ok, json} ->
        {:ok, json}

      {:error, _reason} ->
        Logger.warning("LibriVox answered #{path} with a body that is not JSON")
        {:error, :undecodable}
    end
  end

  defp config(key, default) do
    :lumen_viae
    |> Application.get_env(:librivox, [])
    |> Keyword.get(key, default)
  end
end
