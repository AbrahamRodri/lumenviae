defmodule LumenViae.BotDetection do
  @moduledoc """
  Whether a user agent belongs to an automated client: the predicate that
  keeps crawlers out of the completion figures.

  It lives below the web layer so that an action can ask it: the Rosary
  domain's completion write from the app refuses a crawler itself, so
  every API that runs that action is covered. `LumenViaeWeb.BotDetection` delegates here and reads
  the agent off a connection or a socket.

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

  ## The apps' agents

  Both apps get through, and the reason each does is different.

  The iOS app never sets its agent, so `URLSession` sends CFNetwork's:
  `app/5 CFNetwork/3826.500.111 Darwin/25.0.0`, which names no HTTP
  library on the list.

  An Android HTTP client's default agent would be refused: OkHttp sends
  `okhttp/4.12.0`, and `okhttp` stays on the list because scripts use it.
  So the Android app sends its own,
  `LumenViae-Android/<versionName> (Android <release>; <model>)`, and must
  never fall back to its library's default; Android's stock
  `Dalvik/2.1.0 (Linux; U; Android 14; ...)` would also pass, and is not
  what it sends. `LumenViae.Rosary.Completion.AppSource` reads the same
  agent to tell an Android completion from an iOS one. The tests pin all
  of this.
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
  else could it be? An app could. Its agent is set in the app's codebase
  (by `URLSession` on iOS, by the Android app's HTTP client) and not in
  this one, and a build that stopped sending one would have every
  completion refused with a 403 that nothing in the app is watching for. The whole of the app's analytics
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
end
