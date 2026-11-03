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

  @doc "The plain text of Gutenberg ebook `id`."
  def fetch_text(id) when is_integer(id) do
    path = "/cache/epub/#{id}/pg#{id}.txt"

    options =
      [
        headers: [user_agent: @user_agent],
        receive_timeout: @receive_timeout_ms,
        connect_options: [timeout: @connect_timeout_ms],
        retry: false,
        # The text is read as it stands, never decoded as JSON or the like.
        decode_body: false
      ]
      |> Keyword.merge(config(:req_options, []))

    case Req.get(config(:base_url, "https://www.gutenberg.org") <> path, options) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

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

  defp config(key, default) do
    :lumen_viae
    |> Application.get_env(:spiritual_reading, [])
    |> Keyword.get(key, default)
  end
end
