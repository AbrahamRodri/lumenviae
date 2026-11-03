defmodule LumenViae.Rosary.SpiritualReading.Gutenberg do
  @moduledoc """
  HTTP client for Project Gutenberg's plain-text editions, the text of the
  Spiritual Reading shelf's books: `https://www.gutenberg.org/cache/epub/<id>/pg<id>.txt`,
  the address the apps fetch. The website's server fetches it, so a
  visitor's browser never calls Gutenberg; `LumenViae.Rosary.SpiritualReading.Text`
  cuts and caches what comes back.

  Built as `LumenViae.Office.DivinumOfficium` is: Req with no retries,
  5 seconds to connect, and a longer wait to answer (a whole book is up to
  1.3 MB), the same well-behaved-bot User-Agent, and `:req_options` as the
  test seam (the suite injects `plug: {Req.Test, ...}` through it, so a
  test never touches the network).

      config :lumen_viae, :spiritual_reading,
        base_url: "https://www.gutenberg.org",
        req_options: []

  Answers `{:ok, text}`, `{:error, {:upstream_status, status}}` or
  `{:error, :upstream_unreachable}`.
  """

  require Logger

  @user_agent "Mozilla/5.0 (compatible; LumenViae/1.0; +https://www.lumenviae.org)"

  @receive_timeout_ms 30_000
  @connect_timeout_ms 5_000

  # The largest edition on the shelf is 1.3 MB; nothing honest is near this.
  @maximum_bytes 5_000_000
  # A real edition is plain text and hundreds of kilobytes. A block page, a
  # rate-limit notice or a maintenance page (served as HTML, sometimes with
  # a 200) is neither (iOS LibraryService, the same test).
  @minimum_bytes 50_000

  @doc """
  The plain text of Gutenberg ebook `id`.

  Only a `200` that is `text/plain` and at least 50,000 bytes is the book;
  anything else (a block page, a redirect, which is never followed, or a
  body past 5 MB, whose download is stopped there) is
  `{:error, :upstream_unreachable}` or `{:error, {:upstream_status, status}}`.
  The overall deadline is the caller's (`SpiritualReading.Text`), as
  `receive_timeout` restarts with every chunk.
  """
  def fetch_text(id) when is_integer(id) do
    path = "/cache/epub/#{id}/pg#{id}.txt"

    options =
      [
        headers: [user_agent: @user_agent],
        receive_timeout: @receive_timeout_ms,
        connect_options: [timeout: @connect_timeout_ms],
        retry: false,
        # Never followed, so the request cannot be sent anywhere but
        # Gutenberg's own path for the book.
        redirect: false,
        # Plain bytes on the wire, so the cap counts what is kept.
        compressed: false,
        decode_body: false,
        into: &collect/2
      ]
      |> Keyword.merge(config(:req_options, []))

    case Req.get(config(:base_url, "https://www.gutenberg.org") <> path, options) do
      {:ok, %Req.Response{status: 200} = response} ->
        the_book(response, path)

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Project Gutenberg answered #{status} for #{path}")
        {:error, {:upstream_status, status}}

      {:error, exception} ->
        Logger.warning("Project Gutenberg unreachable: #{Exception.message(exception)}")
        {:error, :upstream_unreachable}
    end
  rescue
    exception ->
      Logger.warning("Project Gutenberg request raised: #{Exception.message(exception)}")
      {:error, :upstream_unreachable}
  end

  # Gathers the body as it arrives, and stops the download once it passes
  # the cap (or the server says in advance that it will).
  defp collect({:data, data}, {request, response}) do
    so_far = Req.Response.get_private(response, :bytes, 0) + byte_size(data)
    response = Req.Response.put_private(response, :bytes, so_far)

    cond do
      declared_too_large?(response) or so_far > @maximum_bytes ->
        {:halt, {request, response |> Req.Response.put_private(:too_large, true)}}

      true ->
        chunks = Req.Response.get_private(response, :chunks, [])
        {:cont, {request, Req.Response.put_private(response, :chunks, [data | chunks])}}
    end
  end

  defp declared_too_large?(response) do
    case Req.Response.get_header(response, "content-length") do
      [length | _rest] ->
        match?({n, ""} when n > @maximum_bytes, Integer.parse(length))

      [] ->
        false
    end
  end

  defp the_book(response, path) do
    type =
      response |> Req.Response.get_header("content-type") |> Enum.join(";") |> String.downcase()

    body =
      response
      |> Req.Response.get_private(:chunks, [])
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    cond do
      Req.Response.get_private(response, :too_large, false) ->
        Logger.warning("Project Gutenberg's #{path} ran past #{@maximum_bytes} bytes; stopped")
        {:error, :upstream_unreachable}

      not String.contains?(type, "text/plain") or byte_size(body) < minimum_bytes() ->
        Logger.warning(
          "Project Gutenberg answered #{path} with #{inspect(type)}, #{byte_size(body)} bytes: not the book"
        )

        {:error, :upstream_unreachable}

      true ->
        {:ok, body}
    end
  end

  # The suite's excerpts of the editions are smaller than a whole book, so
  # config/test.exs lowers this; production keeps iOS's 50,000.
  defp minimum_bytes, do: config(:minimum_bytes, @minimum_bytes)

  defp config(key, default) do
    :lumen_viae
    |> Application.get_env(:spiritual_reading, [])
    |> Keyword.get(key, default)
  end
end
