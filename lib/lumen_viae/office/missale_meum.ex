defmodule LumenViae.Office.MissaleMeum do
  @moduledoc """
  HTTP client for Missale Meum (missalemeum.com, MIT), which serves the
  1962 Missal as bilingual JSON: the propers of a day, the calendar of a
  year and the Order of Mass. The iOS and Android apps call it directly
  (`/en/api/v5/proper/<date>`, `/calendar/<year>`, `/ordo`); the website's
  server calls it instead, so a visitor's browser never does.
  `LumenViae.Office.Missal` reads and caches what comes back.

  Built as `LumenViae.Office.DivinumOfficium` is: Req with no retries,
  5 seconds to connect and 15 to answer, the same well-behaved-bot
  User-Agent, and `:req_options` as the test seam (the suite injects
  `plug: {Req.Test, LumenViae.Office.MissaleMeum}`, so a test never
  touches the network). It follows no redirect (one is an answer that is
  not the Missal's), reads at most 2 MB of a body
  and stops there (the largest it serves, a year's calendar, is about
  66 kB), and asks for no compression. The overall deadline is the
  caller's (`LumenViae.Office.Missal`).

      config :lumen_viae, :missal,
        base_url: "https://www.missalemeum.com",
        req_options: []

  Answers the decoded JSON, `{:error, {:upstream_status, status}}` for a
  non-200 answer, `{:error, :undecodable}` for a 200 that is not JSON (a block page), `{:error, :too_large}`,
  or `{:error, :upstream_unreachable}`.
  """

  require Logger

  @user_agent "Mozilla/5.0 (compatible; LumenViae/1.0; +https://www.lumenviae.org)"

  @receive_timeout_ms 15_000
  @connect_timeout_ms 5_000
  @max_body_bytes 2_000_000

  @doc "The propers of every Mass said on `date`: a list, three on Christmas and All Souls."
  def fetch_proper(%Date{} = date), do: get("/en/api/v5/proper/" <> Date.to_iso8601(date))

  @doc "The 1962 calendar for `year`, a day each: its title, class and colours."
  def fetch_calendar(year) when is_integer(year), do: get("/en/api/v5/calendar/#{year}")

  @doc "The Order of Mass, Asperges to the Last Gospel."
  def fetch_ordo, do: get("/en/api/v5/ordo")

  @doc false
  def max_body_bytes, do: @max_body_bytes

  defp get(path) do
    options =
      [
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

    case Req.get(config(:base_url, "https://www.missalemeum.com") <> path, options) do
      {:ok, %Req.Response{status: 200} = response} ->
        if Req.Response.get_private(response, :too_large) do
          Logger.warning("Missale Meum's answer for #{path} passed #{@max_body_bytes} bytes")
          {:error, :too_large}
        else
          decode(response.body, path)
        end

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Missale Meum answered #{status} for #{path}")
        {:error, {:upstream_status, status}}

      {:error, exception} ->
        Logger.warning("Missale Meum unreachable: #{Exception.message(exception)}")
        {:error, :upstream_unreachable}
    end
  rescue
    exception ->
      Logger.warning("Missale Meum request raised: #{Exception.message(exception)}")
      {:error, :upstream_unreachable}
  end

  # The body gathered a chunk at a time, and dropped the moment it passes
  # the cap.
  defp capped({:data, data}, {request, response}) do
    body = response.body <> data

    if byte_size(body) > @max_body_bytes do
      {:halt, {request, %{Req.Response.put_private(response, :too_large, true) | body: ""}}}
    else
      {:cont, {request, %{response | body: body}}}
    end
  end

  defp decode(body, path) do
    case Jason.decode(body) do
      {:ok, json} ->
        {:ok, json}

      {:error, _reason} ->
        Logger.error("Missale Meum answered #{path} with a body that is not JSON")
        {:error, :undecodable}
    end
  end

  defp config(key, default) do
    :lumen_viae
    |> Application.get_env(:missal, [])
    |> Keyword.get(key, default)
  end
end
