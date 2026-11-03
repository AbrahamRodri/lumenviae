defmodule LumenViaeWeb.Live.Missal.Days do
  @moduledoc """
  The Daily Missal's dates, links and the words it sets beside a day, as
  the iOS app says them (`DailyMissalView`, `MissalVestment`, `DayRank`):
  the date pill ("MON · 2 NOV"), the day's class in plain words, and the
  vestment colour, never bare ("White vestments"). Pure: no fetching here.

  The Missal serves the years the Office serves (1600 to 2200); a date
  outside them, or one that is not a date, is no page.
  """

  alias LumenViae.Office
  alias LumenViaeWeb.Live.Hours.DayRank

  @vestments %{
    "w" => "White",
    "r" => "Red",
    "g" => "Green",
    "v" => "Violet",
    "b" => "Black",
    "p" => "Rose"
  }

  @credit "The traditional Latin Mass (1962 Missal) · texts from Missale Meum"

  @doc "The line at the foot of every Missal page, the app's own."
  def credit, do: @credit

  @doc "Missale Meum's own site, which the credit links to."
  def credit_url, do: "https://www.missalemeum.com"

  # -- Dates ------------------------------------------------------------------

  @doc "A date from the link, `{:ok, date}` only for a date the Missal serves."
  def parse_date(value) when is_binary(value) do
    with {:ok, date} <- Date.from_iso8601(value),
         true <- Office.serves?(date) do
      {:ok, date}
    else
      _ -> :error
    end
  end

  def parse_date(_value), do: :error

  @doc "A year and month from the link, `{:ok, {year, month}}` or `:error`."
  def parse_month(year, month) when is_binary(year) and is_binary(month) do
    # Digits only, with no leading zero: one address a month.
    with true <- Regex.match?(~r/\A[1-9]\d{3}\z/, year),
         true <- Regex.match?(~r/\A[1-9]\d?\z/, month),
         {year, ""} <- Integer.parse(year),
         {month, ""} <- Integer.parse(month),
         true <- month in 1..12,
         true <- Office.serves?(Date.new!(year, month, 1)) do
      {:ok, {year, month}}
    else
      _ -> :error
    end
  rescue
    ArgumentError -> :error
  end

  def parse_month(_year, _month), do: :error

  @doc "The day before or after, or nil past the years the Missal serves."
  def step(%Date{} = date, days) do
    next = Date.add(date, days)
    if Office.serves?(next), do: next
  end

  @doc "\"MON · 2 NOV\", the date pill's words (the app's \"EEE · d MMM\")."
  def pill_date(%Date{} = date),
    do: date |> Calendar.strftime("%a · %-d %b") |> String.upcase()

  @doc "\"Monday, 2 November 2026\"."
  def long_date(%Date{} = date), do: Calendar.strftime(date, "%A, %-d %B %Y")

  @doc "\"November 2026\"."
  def month_title(year, month), do: Calendar.strftime(Date.new!(year, month, 1), "%B %Y")

  # -- Links --------------------------------------------------------------------

  @doc """
  A day's page. English and the first Mass, the defaults, are never
  written: `/missal/2026-12-25?mass=2&lang=both`.
  """
  def day_path(%Date{} = date, language \\ "english", mass \\ 1),
    do: "/missal/" <> Date.to_iso8601(date) <> query(mass: mass, lang: language)

  @doc "Today's page, the visitor's today."
  def today_path(language \\ "english", mass \\ 1),
    do: "/missal" <> query(mass: mass, lang: language)

  @doc "The Order of Mass, in the language being read."
  def ordo_path(language \\ "english", day \\ nil),
    do: "/missal/order-of-mass" <> query(lang: language, day: day)

  @doc """
  A month's calendar, carrying the language being read and, from another
  day's page, that day, for the way back: `/missal/calendar/2026/11?lang=both&day=2026-11-04`.
  """
  def calendar_path(
        date_or_year,
        month_or_language \\ "english",
        language_or_day \\ nil,
        day \\ nil
      )

  def calendar_path(%Date{year: year, month: month}, language, day, _unused),
    do: calendar_path(year, month, language || "english", day)

  def calendar_path(year, month, language, day) when is_integer(year),
    do: "/missal/calendar/#{year}/#{month}" <> query(lang: language || "english", day: day)

  @doc "Where a page reached from a day goes back to: that day, or today."
  def back_path(nil, language), do: today_path(language)
  def back_path(%Date{} = day, language), do: day_path(day, language)

  defp query(pairs) do
    pairs =
      Enum.reject(pairs, fn
        {:mass, 1} -> true
        {:lang, "english"} -> true
        {:day, nil} -> true
        {:day, false} -> true
        _kept -> false
      end)

    pairs =
      Enum.map(pairs, fn
        {k, %Date{} = d} -> {k, Date.to_iso8601(d)}
        pair -> pair
      end)

    if pairs == [], do: "", else: "?" <> URI.encode_query(pairs)
  end

  # -- The day's class and vestments --------------------------------------------

  @doc """
  The day's vestments, `%{letter:, name:, plain:}` ("w", "White", "White
  vestments"), from the first of its colours; nil when it names none.
  """
  def vestment(%{colors: [letter | _rest]}) do
    case Map.fetch(@vestments, letter) do
      {:ok, name} -> %{letter: letter, name: name, plain: name <> " vestments"}
      :error -> nil
    end
  end

  def vestment(_day), do: nil

  @doc "\"Great Feast\", \"Feast\", \"Lesser Feast\" or a weekday, from a Mass or a calendar day."
  def class(%{rank: rank, title: title} = day),
    do: DayRank.plain_missal(rank, title, Map.get(day, :tempora))

  def class(_day), do: nil

  @doc "The class and the colour, as a screen reader hears what the dot shows: \"Feast, red vestments\"."
  def spoken_class(day) do
    [class(day), vestment(day) && String.downcase(vestment(day).plain)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  @doc "\"Also remembered today: St. Vitalis and St. Agricola\", or nil."
  def remembered(%{commemorations: [_ | _] = titles}),
    do: "Also remembered today: " <> Enum.join(titles, " and ")

  def remembered(_day), do: nil
end
