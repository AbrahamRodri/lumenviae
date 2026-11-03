defmodule LumenViae.Rosary.ChantScore do
  @moduledoc """
  A page of a chant's sheet music for the website's full score: the packed
  drawing (`.lvscore`, DEFLATE-compressed drawing operations) the apps
  draw, fetched by the server from the public assets bucket and handed on
  as it is, so the visitor's browser draws it.

  The bucket sends no CORS headers, so a browser on lumenviae.org may
  play a recording from it (media needs none) but may not read a score
  page's bytes; the site therefore serves each page at its own address
  (`/chant/scores/<file>-<sha256 first 12>.lvscore`, the bucket's file
  name) through this module.

  Only a page the Chant Library names is fetched: the name is looked up
  among the library's score pages, and the URL fetched is the library's,
  never one built from the request. What comes back must have the
  library's size and SHA-256, as the apps check a download. Nothing is
  kept on the server: the address names the file's checksum, so the
  answer is cached for a year by the browser (and anything in front of
  the site), and a changed drawing is a new address.

  Built as `LumenViae.Rosary.SpiritualReading.Gutenberg` is: Req with no
  retries and no redirects, short timeouts, and `:req_options` as the
  test seam.

      config :lumen_viae, :chant_scores, req_options: []

  Answers `{:ok, bytes}`, `{:error, :not_found}` (no page of that name)
  or `{:error, :upstream_unreachable}`.
  """

  require Logger

  alias LumenViae.Rosary.Library

  @receive_timeout_ms 15_000
  @connect_timeout_ms 5_000

  @doc "The score page named `name` (`chant-salve-regina-simple-8748a1058c7c.lvscore`)."
  @spec fetch(String.t()) :: {:ok, binary} | {:error, :not_found | :upstream_unreachable}
  def fetch(name) when is_binary(name) do
    case Map.get(pages(), name) do
      nil -> {:error, :not_found}
      page -> download(page)
    end
  end

  @doc "A score page's name on the site: the last segment of its URL in the bucket."
  @spec name(String.t()) :: String.t()
  def name(url) when is_binary(url),
    do: url |> URI.parse() |> Map.get(:path, "") |> Path.basename()

  # Every score page the library names, by its name. Chants share some
  # pages, which are the same file.
  defp pages do
    for chant <- Library.sections(:chant_library)["chants"],
        part <- chant["score"] || [],
        is_binary(part["url"]),
        into: %{},
        do: {name(part["url"]), part}
  end

  defp download(%{"url" => url, "bytes" => bytes, "sha256" => sha256}) do
    options =
      [
        receive_timeout: @receive_timeout_ms,
        connect_options: [timeout: @connect_timeout_ms],
        retry: false,
        redirect: false,
        compressed: false,
        decode_body: false
      ]
      |> Keyword.merge(Application.get_env(:lumen_viae, :chant_scores, [])[:req_options] || [])

    case Req.get(url, options) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        checked(body, bytes, sha256, url)

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("The assets bucket answered #{status} for #{url}")
        {:error, :upstream_unreachable}

      {:error, exception} ->
        Logger.warning(
          "The assets bucket unreachable for #{url}: #{Exception.message(exception)}"
        )

        {:error, :upstream_unreachable}
    end
  rescue
    exception ->
      Logger.warning("A score page's request raised: #{Exception.message(exception)}")
      {:error, :upstream_unreachable}
  end

  defp checked(body, bytes, sha256, url) do
    digest = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

    if byte_size(body) == bytes and digest == sha256 do
      {:ok, body}
    else
      Logger.warning("#{url} is not the page the library names (#{byte_size(body)} bytes)")
      {:error, :upstream_unreachable}
    end
  end
end
