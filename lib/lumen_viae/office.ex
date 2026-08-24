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
  """

  require Logger

  alias LumenViae.Office.Cache
  alias LumenViae.Office.DivinumOfficium
  alias LumenViae.Office.Parser
  alias LumenViae.Office.Versions

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
         sections: parsed.sections,
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

  defp cached(key, load) do
    case Cache.fetch(key) do
      {:ok, value} ->
        {:ok, value}

      :miss ->
        with {:ok, value} <- load.() do
          Cache.put(key, value)
          {:ok, value}
        end
    end
  end

  defp upstream({:ok, html}), do: {:ok, html}
  defp upstream({:error, _reason}), do: {:error, :office_unavailable}

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
