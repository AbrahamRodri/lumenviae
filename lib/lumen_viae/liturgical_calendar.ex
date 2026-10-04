defmodule LumenViae.LiturgicalCalendar do
  @moduledoc """
  Liturgical season calculations and the two weekly Rosary schedules.

  The traditional schedule, the default, and the one the website follows:

    * Monday and Thursday - Joyful
    * Tuesday and Friday - Sorrowful
    * Wednesday and Saturday - Glorious

  The modern schedule, St. John Paul II's (Rosarium Virginis Mariae 38,
  2002), is the same but for two days:

    * Thursday - Luminous
    * Saturday - Joyful

  In both, Sunday follows the season: Joyful in Advent, Sorrowful in Lent,
  Glorious otherwise. RVM gives Sunday to the Glorious but leaves room for
  the season, and keeping the custom in both means the schedules differ
  only on Thursday and Saturday. The Seven Sorrows are on neither.

  Seasons are computed from the Gregorian calendar: Easter via the
  Meeus/Jones/Butcher algorithm, Lent from Ash Wednesday up to Easter,
  and Advent from the Sunday on or after November 27 through December 24.
  `:ordinary` means "not Advent or Lent" for the Rosary schedule, so
  Christmastide and Eastertide fall within it.

  The iOS app computes the same rule on the device (`ScheduleService`),
  and the two must agree on every date: the app's own test cases are
  ported in `test/lumen_viae/liturgical_calendar_test.exs`, with its answer
  for every date of three whole years. The schedule is read on the
  calendar day the date names, which turns at midnight. It is not the
  app's prayer day, which turns at four in the morning and decides only
  what has been prayed: a Rosary begun at half past midnight on a
  Wednesday prays Wednesday's mysteries.

  The words for the days a set is prayed (`days_prayed/2`,
  `days_in_words/2`) are the app's own, character for character.

  `LumenViae.Rosary.RosaryContent.Schedule` serves these rules as the
  content document's `schedule` section, so a client can apply them
  offline (docs/JSON_API.md, "The day's mysteries"). A change to a rule or
  a word here moves that section: date it there.
  """

  @type schedule :: :traditional | :modern
  @type category :: :joyful | :sorrowful | :glorious | :luminous | :seven_sorrows
  @type season :: :advent | :lent | :ordinary

  @schedules [:traditional, :modern]
  @categories [:joyful, :sorrowful, :glorious, :luminous, :seven_sorrows]

  # Monday first, as Date.day_of_week/1 numbers the days
  @weekday_names ~w(Monday Tuesday Wednesday Thursday Friday Saturday)

  # The Sundays in the order the app names them: the ordinary Sunday, then
  # Advent's, then Lent's
  @sunday_words [
    ordinary: "Sunday",
    advent: "Sundays of Advent",
    lent: "Sundays of Lent"
  ]

  @doc """
  The two schedules, the default first.
  """
  @spec schedules() :: [schedule()]
  def schedules, do: @schedules

  @doc """
  The schedule followed unless another is chosen: `:traditional`.
  """
  @spec default_schedule() :: schedule()
  def default_schedule, do: :traditional

  @doc """
  The five categories, in the order the app presents them.
  """
  @spec categories() :: [category()]
  def categories, do: @categories

  @doc """
  Returns the recommended mystery set for the given date on a schedule
  (`:traditional` unless another is named), with season-aware Sundays.
  """
  @spec recommended_mysteries(Date.t(), schedule()) :: category()
  def recommended_mysteries(%Date{} = date, schedule \\ :traditional)
      when schedule in @schedules do
    weekday_mysteries(Date.day_of_week(date), schedule) || sunday_mysteries(season(date))
  end

  @doc """
  A weekday's mysteries on a schedule, the day numbered as
  `Date.day_of_week/1` numbers it (1 is Monday). `nil` for Sunday (7),
  which follows the season: see `sunday_mysteries/1`.
  """
  @spec weekday_mysteries(1..7, schedule()) :: category() | nil
  def weekday_mysteries(day_of_week, schedule) when schedule in @schedules,
    do: weekday(day_of_week, schedule)

  defp weekday(1, _schedule), do: :joyful
  defp weekday(2, _schedule), do: :sorrowful
  defp weekday(3, _schedule), do: :glorious
  defp weekday(4, :traditional), do: :joyful
  defp weekday(4, :modern), do: :luminous
  defp weekday(5, _schedule), do: :sorrowful
  defp weekday(6, :traditional), do: :glorious
  defp weekday(6, :modern), do: :joyful
  defp weekday(7, _schedule), do: nil

  @doc """
  Sunday's mysteries in a season, the same on both schedules.
  """
  @spec sunday_mysteries(season()) :: category()
  def sunday_mysteries(:advent), do: :joyful
  def sunday_mysteries(:lent), do: :sorrowful
  def sunday_mysteries(:ordinary), do: :glorious

  @doc """
  The sets a schedule's week prays, in the week's order from Monday:
  Joyful, Sorrowful, Glorious, and on the modern schedule the Luminous,
  Thursday's. Sunday's seasons add none the weekdays have not. The app's
  home grid is these, then the Seven Sorrows.
  """
  @spec week(schedule()) :: [category()]
  def week(schedule) when schedule in @schedules do
    1..6
    |> Enum.map(&weekday_mysteries(&1, schedule))
    |> Enum.uniq()
  end

  @doc """
  The days a set is prayed on a schedule, in words: `"Monday, Thursday,
  Sundays of Advent"`. `nil` for a set the schedule never reaches: the
  Luminous on the traditional schedule, the Seven Sorrows on either.
  """
  @spec days_prayed(category(), schedule()) :: String.t() | nil
  def days_prayed(category, schedule) when category in @categories and schedule in @schedules do
    weekdays =
      for {name, day} <- Enum.with_index(@weekday_names, 1),
          weekday_mysteries(day, schedule) == category,
          do: name

    sundays =
      for {season, words} <- @sunday_words, sunday_mysteries(season) == category, do: words

    case weekdays ++ sundays do
      [] -> nil
      days -> Enum.join(days, ", ")
    end
  end

  @doc """
  The days a set is prayed on a schedule, in the words the app shows
  under its name: `days_prayed/2`, or for a set the schedule never
  reaches, when it is kept. The Seven Sorrows are kept on Fridays and on
  their feast; the Luminous, on the traditional schedule, on any day.
  """
  @spec days_in_words(category(), schedule()) :: String.t()
  def days_in_words(category, schedule) do
    case {days_prayed(category, schedule), category} do
      {nil, :seven_sorrows} -> "Fridays, and on her feast, September 15"
      {nil, _} -> "Any day you choose"
      {days, _} -> days
    end
  end

  @doc """
  Returns the liturgical season for a date: :advent, :lent, or :ordinary.

  :ordinary here means "not Advent or Lent" for the purpose of the
  Rosary schedule, not the liturgical Tempus per Annum.
  """
  @spec season(Date.t()) :: season()
  def season(%Date{} = date) do
    cond do
      lent?(date) -> :lent
      advent?(date) -> :advent
      true -> :ordinary
    end
  end

  @doc """
  The dated Lent and Advent of each year in a range, in calendar order,
  each with its first and last day (both inclusive). Every date outside
  them is `:ordinary`.

      iex> LumenViae.LiturgicalCalendar.seasons(2026..2026)
      [
        %{season: :lent, starts_on: ~D[2026-02-18], ends_on: ~D[2026-04-04]},
        %{season: :advent, starts_on: ~D[2026-11-29], ends_on: ~D[2026-12-24]}
      ]
  """
  @spec seasons(Range.t()) :: [%{season: season(), starts_on: Date.t(), ends_on: Date.t()}]
  def seasons(first..last//1) do
    Enum.flat_map(first..last//1, fn year ->
      [
        %{season: :lent, starts_on: ash_wednesday(year), ends_on: Date.add(easter(year), -1)},
        %{season: :advent, starts_on: advent_start(year), ends_on: Date.new!(year, 12, 24)}
      ]
    end)
  end

  @doc """
  Easter Sunday for the given year (Gregorian, Meeus/Jones/Butcher).
  """
  @spec easter(integer()) :: Date.t()
  def easter(year) do
    a = rem(year, 19)
    b = div(year, 100)
    c = rem(year, 100)
    d = div(b, 4)
    e = rem(b, 4)
    f = div(b + 8, 25)
    g = div(b - f + 1, 3)
    h = rem(19 * a + b - d - g + 15, 30)
    i = div(c, 4)
    k = rem(c, 4)
    l = rem(32 + 2 * e + 2 * i - h - k, 7)
    m = div(a + 11 * h + 22 * l, 451)
    month = div(h + l - 7 * m + 114, 31)
    day = rem(h + l - 7 * m + 114, 31) + 1

    Date.new!(year, month, day)
  end

  @doc """
  Ash Wednesday for the given year (46 days before Easter).
  """
  @spec ash_wednesday(integer()) :: Date.t()
  def ash_wednesday(year), do: Date.add(easter(year), -46)

  @doc """
  The first Sunday of Advent: the Sunday on or after November 27.
  """
  @spec advent_start(integer()) :: Date.t()
  def advent_start(year) do
    nov_27 = Date.new!(year, 11, 27)
    Date.add(nov_27, rem(7 - Date.day_of_week(nov_27), 7))
  end

  defp lent?(date) do
    year = date.year

    Date.compare(date, ash_wednesday(year)) != :lt and
      Date.compare(date, easter(year)) == :lt
  end

  defp advent?(date) do
    year = date.year

    Date.compare(date, advent_start(year)) != :lt and
      Date.compare(date, Date.new!(year, 12, 24)) != :gt
  end
end
