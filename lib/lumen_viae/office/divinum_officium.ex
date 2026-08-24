defmodule LumenViae.Office.DivinumOfficium do
  @moduledoc """
  HTTP client for a Divinum Officium instance - the open-source engine
  (MIT, github.com/DivinumOfficium/divinum-officium) that assembles the
  pre-Vatican II Office for a date under a given set of rubrics.

  ## Configuration

      config :lumen_viae, :office,
        base_url: "https://www.divinumofficium.com",
        req_options: []

  `:base_url` exists so production can point at a self-hosted copy of the
  engine (the project publishes a Docker image) without a code change;
  the public site is the default. `:req_options` is the test seam - the
  suite injects `plug: {Req.Test, LumenViae.Office.DivinumOfficium}`
  through it, the same arrangement `LumenViae.Services.Geolocation` uses.

  The public site refuses requests whose User-Agent does not begin with
  "Mozilla/5.0", so the client sends the standard well-behaved-bot form:
  Mozilla prefix, then a token naming this app and where to reach us.

  Answers are raw HTML; `LumenViae.Office.Parser` turns them into data.
  Errors are `{:error, {:upstream_status, status}}` for a non-200 answer
  and `{:error, :upstream_unreachable}` for anything transport-shaped.
  Retries are the caller's business (`retry: false`).
  """

  require Logger

  @user_agent "Mozilla/5.0 (compatible; LumenViae/1.0; +https://www.lumenviae.org)"

  @receive_timeout_ms 15_000
  @connect_timeout_ms 5_000

  @doc """
  The assembled office of one hour: HTML with Latin and the requested
  translation side by side.
  """
  def fetch_hour(%Date{} = date, do_hour, do_version, do_language) do
    get("/cgi-bin/horas/officium.pl",
      date1: format_date(date),
      command: "pray" <> do_hour,
      version: do_version,
      lang2: do_language
    )
  end

  @doc """
  The engine's calendar for one month under one set of rubrics: a row per
  day with its celebration, rank and season.
  """
  def fetch_kalendar(year, month, do_version) do
    get("/cgi-bin/horas/kalendar.pl",
      kmonth: month,
      kyear: year,
      version: do_version
    )
  end

  @doc """
  The public URL an office was (or would be) assembled from. Served in API
  responses as source attribution, and always against the public site even
  when the fetch itself went to a self-hosted instance.
  """
  def public_url(%Date{} = date, do_hour, do_version, do_language) do
    query =
      URI.encode_query(
        date1: format_date(date),
        command: "pray" <> do_hour,
        version: do_version,
        lang2: do_language
      )

    "https://www.divinumofficium.com/cgi-bin/horas/officium.pl?" <> query
  end

  defp get(path, params) do
    options =
      [
        params: params,
        headers: [user_agent: @user_agent],
        receive_timeout: @receive_timeout_ms,
        connect_options: [timeout: @connect_timeout_ms],
        retry: false
      ]
      |> Keyword.merge(config(:req_options, []))

    case Req.get(base_url() <> path, options) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Divinum Officium answered #{status} for #{path}")
        {:error, {:upstream_status, status}}

      {:error, exception} ->
        Logger.warning("Divinum Officium unreachable: #{Exception.message(exception)}")
        {:error, :upstream_unreachable}
    end
  rescue
    exception ->
      Logger.warning("Divinum Officium request raised: #{Exception.message(exception)}")
      {:error, :upstream_unreachable}
  end

  defp format_date(date), do: Calendar.strftime(date, "%m-%d-%Y")

  defp base_url, do: config(:base_url, "https://www.divinumofficium.com")

  defp config(key, default) do
    :lumen_viae
    |> Application.get_env(:office, [])
    |> Keyword.get(key, default)
  end
end
