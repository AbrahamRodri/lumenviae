defmodule LumenViae.LiturgicalCalendar do
  @moduledoc """
  Liturgical season calculations and the traditional daily Rosary schedule.

  The traditional weekly schedule assigns:

    * Monday and Thursday - Joyful
    * Tuesday and Friday - Sorrowful
    * Wednesday and Saturday - Glorious
    * Sunday - varies by season: Joyful in Advent, Sorrowful in Lent,
      Glorious otherwise

  Seasons are computed from the Gregorian calendar: Easter via the
  Meeus/Jones/Butcher algorithm, Lent from Ash Wednesday to Easter,
  and Advent from the fourth Sunday before Christmas through December 24.
  """

  @doc """
  Returns the recommended mystery set (:joyful, :sorrowful, or :glorious)
  for the given date, following the traditional schedule with
  season-aware Sundays.
  """
  def recommended_mysteries(%Date{} = date) do
    case Date.day_of_week(date) do
      1 -> :joyful
      2 -> :sorrowful
      3 -> :glorious
      4 -> :joyful
      5 -> :sorrowful
      6 -> :glorious
      7 -> sunday_mysteries(date)
    end
  end

  @doc """
  Returns the liturgical season for a date: :advent, :lent, or :ordinary.

  :ordinary here means "not Advent or Lent" for the purpose of the
  Rosary schedule, not the liturgical Tempus per Annum.
  """
  def season(%Date{} = date) do
    cond do
      lent?(date) -> :lent
      advent?(date) -> :advent
      true -> :ordinary
    end
  end

  @doc """
  Easter Sunday for the given year (Gregorian, Meeus/Jones/Butcher).
  """
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
  def ash_wednesday(year), do: Date.add(easter(year), -46)

  @doc """
  The first Sunday of Advent: the Sunday on or after November 27.
  """
  def advent_start(year) do
    nov_27 = Date.new!(year, 11, 27)
    Date.add(nov_27, rem(7 - Date.day_of_week(nov_27), 7))
  end

  defp sunday_mysteries(date) do
    case season(date) do
      :advent -> :joyful
      :lent -> :sorrowful
      :ordinary -> :glorious
    end
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
