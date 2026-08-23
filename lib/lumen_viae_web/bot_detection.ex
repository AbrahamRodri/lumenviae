defmodule LumenViaeWeb.BotDetection do
  @moduledoc """
  Decides whether a request came from an automated client.

  Used to keep crawlers out of the completion figures. It is one layer of
  two and the softer one: an agent string is whatever the caller says it
  is, so this catches the honest majority and the rate limit in
  `LumenViae.RateLimit` catches the rest. Nothing here should be read as a
  security boundary.

  The two costs are
  not symmetrical, and the matching below is shaped by that: a false
  negative inflates a count, while a false positive silently discards a
  Rosary a real person actually prayed. The second is worse, because it is
  invisible - nothing anywhere reports the completions that were dropped.

  ## Why not simply look for "bot" in the string

  Because `Mozilla/5.0 (Linux; Android 10; Cubot X30)` contains it, and so
  does every other phone in that family. A bare substring test throws away
  real prayers to catch a crawler that was not there.

  So a generic match must be bounded on the left by something that is not a
  letter - `Bot/1.0`, `some-bot/2`, `; spider)` - and anything that runs a
  word straight into it, `Googlebot` and its many relatives, has to be
  named outright in `@named_agents`. That list is the part worth extending
  when a new crawler shows up in the logs.
  """

  # Crawlers whose name ends in a token this would otherwise miss, plus the
  # HTTP libraries that show up when something is scripted rather than
  # crawled. Not exhaustive and does not need to be: an unknown crawler
  # that formats its agent conventionally is caught by @generic below, and
  # one that disguises itself as a browser was never going to be caught by
  # a user agent test at all - that is what the rate limit is for.
  @named_agents ~w(
    googlebot bingbot yandexbot baiduspider duckduckbot applebot facebookexternalhit
    ahrefsbot semrushbot mj12bot dotbot petalbot bytespider seznambot
    gptbot claudebot claude-web anthropic-ai perplexitybot ccbot amazonbot
    ia_archiver archive.org_bot screaming frog lighthouse pingdom uptimerobot
    curl wget python-requests python-urllib scrapy httpx aiohttp
    go-http-client java/ okhttp libwww-perl node-fetch axios got/ postmanruntime
    insomnia headlesschrome phantomjs puppeteer playwright selenium
    slackbot twitterbot telegrambot discordbot whatsapp linkedinbot embedly
  )

  # A conventionally formatted agent this does not know by name. Left-bound
  # so it cannot fire in the middle of a word.
  @generic ~r/(^|[^a-z])(bot|crawler|spider|slurp|scraper|crawl)([^a-z]|$)/

  @doc """
  Whether a user agent string belongs to an automated client.

  ## A missing agent is not an accusation

  It would be tempting to read one as a bot - no browser omits it, so what
  else could it be? The iOS app could. Its agent is set by `URLSession`,
  which lives in the app's codebase and not in this one, and a build that
  stopped sending one would have every completion refused with a 403 that
  nothing in the app is watching for. The whole of the app's analytics
  would go quiet and the first symptom would be a dashboard that gradually
  looked wrong.

  Weighed against that, what refusing a blank agent actually buys is small.
  Every scripted client worth naming announces itself - `curl`, `wget`,
  `python-requests` are all caught below - and one that sends nothing is
  one edit away from sending `Mozilla/5.0`, which no agent test was ever
  going to catch. That caller is the rate limit's problem, and the rate
  limit does not care what it calls itself.

  So an unknown agent is unknown, and the answer here is `false`.
  """
  def bot?(nil), do: false
  def bot?(""), do: false

  def bot?(user_agent) when is_binary(user_agent) do
    agent = String.downcase(user_agent)

    Enum.any?(@named_agents, &String.contains?(agent, &1)) or Regex.match?(@generic, agent)
  end

  def bot?(_other), do: false

  @doc """
  The user agent on a `Plug.Conn`, or `nil`.
  """
  def user_agent(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [value | _] -> value
      [] -> nil
    end
  end

  @doc """
  The user agent from a LiveView socket's `connect_info`.
  """
  def user_agent_from_connect_info(%{user_agent: user_agent}), do: user_agent
  def user_agent_from_connect_info(_other), do: nil
end
