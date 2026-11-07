defmodule LumenViae.Office do
  @moduledoc """
  The Divine Office domain: the pre-Vatican II Breviarium Romanum, served
  as data.

  This is the domain's only public entry point, the way `LumenViae.Rosary`
  is for the Rosary. It owns no tables and never touches the Repo: the
  rubrical engine is Divinum Officium (fetched by
  `LumenViae.Office.DivinumOfficium`, parsed by `LumenViae.Office.Parser`),
  and every parsed answer is held in `LumenViae.Office.Cache`, so each
  distinct office is fetched from the engine once per machine per month.

  All three fetch functions take the web layer's raw string parameters and
  do their own validation, answering `{:error, {:bad_request, message}}`
  with the valid vocabulary spelled out, so controllers stay thin and the
  fallback controller renders every failure. Upstream trouble - the engine
  unreachable, answering non-200, or answering markup the parser no longer
  recognizes - is collapsed to `{:error, :office_unavailable}`: one
  retryable answer for the client, with the distinction preserved in the
  server log.

  The website's Daily Missal reads the 1962 Missal through this domain
  too (`fetch_mass/1`, `fetch_missal_calendar/1`, `fetch_order_of_mass/0`):
  Missale Meum fetched by the server and held in the same cache, through
  `LumenViae.Office.Missal`. No API serves it; the apps call Missale Meum
  themselves.

  ## As an Ash domain

  The module is also an `Ash.Domain`, so GraphQL and the v2 JSON:API can
  reach the Office through `LumenViae.Office.Breviary`, a resource with no
  table whose generic actions call the fetch functions below. The v1 REST
  controller keeps calling those functions directly. All three APIs
  therefore share one validation, one engine client and one cache.
  """
  use Ash.Domain,
    otp_app: :lumen_viae,
    extensions: [AshGraphql.Domain, AshJsonApi.Domain]

  require Logger

  alias LumenViae.Office.Breviary
  alias LumenViae.Office.Cache
  alias LumenViae.Office.DivinumOfficium
  alias LumenViae.Office.FallbackHeadings
  alias LumenViae.Office.Missal
  alias LumenViae.Office.Parser
  alias LumenViae.Office.Versions

  graphql do
    queries do
      action Breviary, :office_hour, :hour
      action Breviary, :office_hours, :hours
      action Breviary, :office_day, :day
      action Breviary, :office_calendar, :calendar
      action Breviary, :office_vocabulary, :vocabulary
    end
  end

  # The same actions under /api/v2/office, for a client that calls v2 only
  # (Android). Each answers with its value as the JSON body, not a JSON:API
  # resource object: an office is text, not a record with an id. The
  # version and language are query parameters, as in v1. See
  # docs/JSON_API.md, "The Divine Office".
  json_api do
    prefix "/api/v2"

    open_api do
      group_by :resource
    end

    routes do
      base_route "/office", Breviary do
        route :get, "/vocabulary", :vocabulary do
          name "getOfficeVocabulary"
        end

        route :get, "/calendar/:year/:month", :calendar do
          name "getOfficeCalendar"
        end

        route :get, "/days/:date", :day do
          name "getOfficeDay"
        end

        route :get, "/days/:date/hours", :hours do
          name "listOfficeHours"
        end

        route :get, "/days/:date/hours/:hour", :hour do
          name "getOfficeHour"
        end
      end
    end
  end

  resources do
    resource Breviary
  end

  @source_name "The Divinum Officium Project"

  # The engine covers the Gregorian calendar; outside this window it
  # answers nonsense rather than errors, so the window is enforced here.
  @first_year 1600
  @last_year 2200

  @doc """
  The full text of one canonical hour on one date: Latin and the requested
  translation, section by section.

  `params` may carry "version" and "language" slugs; see
  `LumenViae.Office.Versions` for the vocabulary and the defaults.
  """
  def fetch_hour(date_param, hour_param, params \\ %{}) do
    with {:ok, date} <- parse_date(date_param),
         {:ok, hour} <- parse_hour_slug(hour_param),
         {:ok, version} <- parse_version(params),
         {:ok, language} <- parse_language(params) do
      cached({:hour, version.slug, language.slug, hour.slug, date}, fn ->
        load_hour(date, hour, version, language)
      end)
    end
  end

  @doc """
  One day's place in the calendar: its celebration and rank, the season or
  commemoration line, and any rubric note - without fetching any hour.
  """
  def fetch_day(date_param, params \\ %{}) do
    with {:ok, date} <- parse_date(date_param),
         {:ok, version} <- parse_version(params),
         {:ok, days} <- calendar_days(date.year, date.month, version) do
      case Enum.find(days, &(&1.date == date)) do
        nil -> {:error, :not_found}
        day -> {:ok, Map.put(day, :version, version.slug)}
      end
    end
  end

  @doc """
  The liturgical calendar for one month under one set of rubrics.
  """
  def fetch_calendar(year_param, month_param, params \\ %{}) do
    with {:ok, year} <- parse_year(year_param),
         {:ok, month} <- parse_month(month_param),
         {:ok, version} <- parse_version(params),
         {:ok, days} <- calendar_days(year, month, version) do
      {:ok, %{year: year, month: month, version: version.slug, days: days}}
    end
  end

  # -- The Daily Missal ----------------------------------------------------

  @doc """
  Every Mass said on `date` under the 1962 Missal, from Missale Meum
  through this machine's cache: `{:ok, [mass]}` (usually one, three on
  Christmas and All Souls, none for a day it has no texts for) or
  `{:error, :missal_unavailable}`, a failure held a minute. Each mass is
  `%{id:, title:, description:, rank:, colors:, tempora:, commemorations:,
  sections:}`, each section `%{id:, label:, body:}` and each passage of a
  body `[english, latin]`. For the website's Missal; the apps call Missale
  Meum themselves. See `LumenViae.Office.Missal`.
  """
  def fetch_mass(%Date{} = date), do: Missal.propers(date)

  @doc """
  The Missal's calendar for `year`, `{:ok, %{date => %{title:, rank:,
  colors:, commemorations:}}}`, or `{:error, :missal_unavailable}`.
  """
  def fetch_missal_calendar(year) when is_integer(year), do: Missal.calendar(year)

  @doc """
  The Order of Mass, every Mass's fixed parts, `{:ok, [section]}` (a
  passage of a rubric is a single text), or `{:error, :missal_unavailable}`.
  """
  def fetch_order_of_mass, do: Missal.ordo()

  @doc """
  Whether `date` falls in the years the Office serves, so a page can
  answer 404 for a date outside them before asking the engine anything.
  """
  def serves?(%Date{year: year}), do: year in @first_year..@last_year

  @doc """
  The vocabulary a client needs before asking for anything else: the
  version, hour and language slugs this API accepts, and the defaults.
  """
  def vocabulary do
    %{
      versions: Versions.versions(),
      hours: Versions.hours(),
      languages: Versions.languages(),
      defaults: %{version: Versions.default_version(), language: Versions.default_language()}
    }
  end

  @doc """
  The attribution every hour carries, because the texts are the Divinum
  Officium project's work, not ours.
  """
  def source(url), do: %{name: @source_name, url: url}

  @doc """
  Fetches every hour of each date, in the default version and language, and
  the months they fall in, so the first request for them is served from the
  cache instead of waiting on the engine.

  Warms this machine's cache only; the cache is per machine, so
  `LumenViae.Office.Jobs.WarmCache` calls this on every node. What is
  already cached costs nothing. Answers `%{warmed:, cached:, failed:,
  skipped:}`, counting hours and months together.

  The first fetch that fails ends the run: the rest are counted as
  `skipped` and left to be fetched on demand. An engine that is down
  answers every request the same way, and asking it thirty more times
  would only log thirty more warnings.
  """
  def warm(dates) when is_list(dates) do
    params = %{"version" => Versions.default_version(), "language" => Versions.default_language()}

    calendar =
      dates
      |> Enum.map(&{&1.year, &1.month})
      |> Enum.uniq()
      |> Enum.map(fn {year, month} ->
        {{:kalendar, params["version"], year, month},
         fn -> fetch_calendar(year, month, params) end}
      end)

    hours =
      for date <- dates, hour <- Versions.hours() do
        {{:hour, params["version"], params["language"], hour.slug, date},
         fn -> fetch_hour(Date.to_iso8601(date), hour.slug, params) end}
      end

    entries = calendar ++ hours
    counts = %{warmed: 0, cached: 0, failed: 0, skipped: 0}

    entries
    |> Enum.with_index(1)
    |> Enum.reduce_while(counts, fn {{key, fetch}, done}, acc ->
      case warm_entry(key, fetch) do
        :failed -> {:halt, %{acc | failed: 1, skipped: length(entries) - done}}
        outcome -> {:cont, Map.update!(acc, outcome, &(&1 + 1))}
      end
    end)
  end

  defp warm_entry(key, fetch) do
    with :miss <- Cache.fetch(key),
         {:ok, _value} <- fetch.() do
      :warmed
    else
      {:ok, _cached} -> :cached
      {:error, _reason} -> :failed
    end
  end

  @doc """
  Whether the engine answers right now: the current month's calendar,
  fetched past the cache and parsed. `:ok`, or `{:error, reason}`. For
  the console's System screen and `mix lumen_viae.doctor`; it wakes a
  suspended engine, as any request does.
  """
  def ping do
    today = Date.utc_today()
    version = Versions.default_version()
    {:ok, %{do_version: do_version}} = Versions.fetch_version(version)

    with {:ok, html} <- DivinumOfficium.fetch_kalendar(today.year, today.month, do_version),
         {:ok, _days} <- Parser.parse_kalendar(html, today.year, today.month) do
      :ok
    end
  end

  @doc "How much this machine's cache holds: `%{entries:, bytes:}`."
  def cache_stats, do: Cache.stats()

  @doc "The job that warms every machine's cache, for the console's last-run figure."
  def warm_cache_worker, do: LumenViae.Office.Jobs.WarmCache

  @doc "Empties this machine's cache, so the next request for anything refetches it."
  def clear_cache, do: Cache.reset()

  # -- Loading -------------------------------------------------------------

  defp load_hour(date, hour, version, language) do
    with {:ok, html} <-
           upstream(
             DivinumOfficium.fetch_hour(
               date,
               hour.do_hour,
               version.do_version,
               language.do_language
             )
           ),
         {:ok, parsed} <- parse(Parser.parse_hour(html), :hour) do
      {:ok,
       %{
         date: date,
         hour: hour.slug,
         version: version.slug,
         language: language.slug,
         celebration: parsed.celebration,
         tempora: parsed.tempora,
         sections: FallbackHeadings.translate(parsed.sections, language.slug),
         source_url:
           DivinumOfficium.public_url(
             date,
             hour.do_hour,
             version.do_version,
             language.do_language
           )
       }}
    end
  end

  defp calendar_days(year, month, version) do
    cached({:kalendar, version.slug, year, month}, fn ->
      with {:ok, html} <-
             upstream(DivinumOfficium.fetch_kalendar(year, month, version.do_version)),
           {:ok, days} <- parse(Parser.parse_kalendar(html, year, month), :kalendar) do
        {:ok, days}
      end
    end)
  end

  # -- Fetch limits ----------------------------------------------------------
  #
  # Any date from 1600 to 2200 is a key of its own, and each cold key is one
  # request to the engine, so a crawler walking dates could load the engine
  # and grow the cache without end. As the Missal does: cold loads share a
  # budget a minute per machine, past which the answer is "unavailable"; a
  # failed key is held for a few minutes, and an engine that cannot be
  # reached holds every cold key for a minute, so an outage costs no
  # request its full timeout; and a date far from today is kept an hour,
  # not a month, so the cache holds the dates people pray.
  @per_minute 60
  @key_hold_ms :timer.minutes(5)
  @outage_hold_ms :timer.minutes(1)
  @near_days 42
  @far_ttl_ms :timer.hours(1)

  defp cached(key, load), do: Cache.fetch_or_load(key, fn -> limited_load(key, load) end)

  defp limited_load(key, load) do
    if held?(key) or not admitted?() do
      {:error, :office_unavailable}
    else
      case load.() do
        {:ok, value} ->
          case ttl(key, Date.utc_today()) do
            nil -> {:ok, value}
            ttl_ms -> {:ok, value, ttl_ms}
          end

        {:error, :office_unavailable} = error ->
          Cache.put({:office_failed, key}, true, @key_hold_ms)
          error

        other ->
          other
      end
    end
  end

  defp held?(key),
    do: Cache.fetch({:office_failed, key}) != :miss or Cache.fetch({:office_failed, :any}) != :miss

  # Counted per test namespace in the suite, one count in production.
  defp admitted? do
    per_minute =
      Application.get_env(:lumen_viae, :office_limits, []) |> Keyword.get(:per_minute, @per_minute)

    match?(
      {:allow, _count},
      LumenViae.Hammer.hit("office_fetch:#{inspect(Cache.namespace())}", 60_000, per_minute)
    )
  end

  @doc false
  # How long a loaded key is kept: an hour for a date (or month) more than
  # six weeks from today, else the cache's month (nil).
  def ttl({:hour, _version, _language, _hour, %Date{} = date}, today), do: far(date, today)

  def ttl({:kalendar, _version, year, month}, today) do
    first = Date.new!(year, month, 1)
    last = Date.end_of_month(first)

    if Date.compare(today, first) != :lt and Date.compare(today, last) != :gt,
      do: nil,
      else: far(Enum.min_by([first, last], &abs(Date.diff(&1, today))), today)
  end

  def ttl(_key, _today), do: nil

  defp far(date, today), do: if(abs(Date.diff(date, today)) > @near_days, do: @far_ttl_ms)

  defp upstream({:ok, html}), do: {:ok, html}

  # The engine could not be reached or answered an error: every cold key
  # waits a minute rather than its own full timeout.
  defp upstream({:error, _reason}) do
    Cache.put({:office_failed, :any}, true, @outage_hold_ms)
    {:error, :office_unavailable}
  end

  defp parse({:ok, parsed}, _what), do: {:ok, parsed}

  # The engine answered 200 with markup the parser does not recognize -
  # either the upstream changed shape or it rendered an error page.
  defp parse({:error, reason}, what) do
    Logger.error("Divinum Officium #{what} page did not parse: #{inspect(reason)}")
    {:error, :office_unavailable}
  end

  # -- Parameter validation ------------------------------------------------

  defp parse_date(param) when is_binary(param) do
    case Date.from_iso8601(param) do
      {:ok, %Date{year: year} = date} when year in @first_year..@last_year ->
        {:ok, date}

      {:ok, _out_of_range} ->
        {:error, {:bad_request, "date must fall between #{@first_year} and #{@last_year}"}}

      {:error, _reason} ->
        {:error, {:bad_request, "date must be an ISO 8601 date, like 2026-08-24"}}
    end
  end

  defp parse_date(_other), do: {:error, {:bad_request, "date must be an ISO 8601 date"}}

  defp parse_hour_slug(param) do
    case Versions.fetch_hour(param) do
      {:ok, hour} -> {:ok, hour}
      :error -> {:error, unknown("hour", param, Versions.hour_slugs())}
    end
  end

  defp parse_version(params) do
    slug = Map.get(params, "version", Versions.default_version())

    case Versions.fetch_version(slug) do
      {:ok, version} -> {:ok, version}
      :error -> {:error, unknown("version", slug, Versions.version_slugs())}
    end
  end

  defp parse_language(params) do
    slug = Map.get(params, "language", Versions.default_language())

    case Versions.fetch_language(slug) do
      {:ok, language} -> {:ok, language}
      :error -> {:error, unknown("language", slug, Versions.language_slugs())}
    end
  end

  defp parse_year(param) do
    case Integer.parse(to_string(param)) do
      {year, ""} when year in @first_year..@last_year ->
        {:ok, year}

      _out_of_range ->
        {:error, {:bad_request, "year must fall between #{@first_year} and #{@last_year}"}}
    end
  end

  defp parse_month(param) do
    case Integer.parse(to_string(param)) do
      {month, ""} when month in 1..12 -> {:ok, month}
      _not_a_month -> {:error, {:bad_request, "month must fall between 1 and 12"}}
    end
  end

  defp unknown(name, value, valid) do
    {:bad_request, "unknown #{name} #{inspect(value)}; valid #{name}s: #{Enum.join(valid, ", ")}"}
  end
end
