defmodule LumenViaeWeb.Live.Consecration.Plan do
  @moduledoc """
  A reader's Consecration as the website keeps it: in this browser's
  `localStorage` alone, read and written by the `ConsecrationPlan` hook
  (`assets/js/hooks/consecration_plan.js`), never sent anywhere else. The
  hook hands the page what it holds when the page connects; this module
  reads that, and does the app's date arithmetic over it
  (`MarianFeastDay`, `FeastPreparation` and `ConsecrationProgress` on iOS).

  A plan is `%{start: Date, feast_id: id | nil, completed_at: string | nil}`:
  Day 1 at `start`, Consecration Day (Day 34) 33 days after it. The days
  prayed are a sorted list of day numbers. Pure: no storage, no queries.
  """

  @last_day 34

  @doc "The last day: Consecration Day."
  def last_day, do: @last_day

  # ---- What the browser hands the page

  @doc """
  The plan the hook read, or nil for none or anything that is not one: a
  map with a `start` that is a date (`YYYY-MM-DD`). A `feast_id` the
  document does not name is dropped; `completed_at` is kept as written.
  """
  def parse(%{"start" => start} = raw, feasts) when is_binary(start) do
    case Date.from_iso8601(start) do
      {:ok, date} ->
        feast_id = raw["feast_id"]

        %{
          start: date,
          feast_id:
            if(is_binary(feast_id) and Enum.any?(feasts, &(&1.id == feast_id)), do: feast_id),
          completed_at: if(is_binary(raw["completed_at"]), do: raw["completed_at"])
        }

      _error ->
        nil
    end
  end

  def parse(_raw, _feasts), do: nil

  @doc "The days prayed the hook read: whole numbers from 1 to 34, each once, in order."
  def parse_done(list) when is_list(list) do
    list
    |> Enum.filter(&(is_integer(&1) and &1 in 1..@last_day))
    |> Enum.uniq()
    |> Enum.sort()
  end

  def parse_done(_other), do: []

  @doc "The visitor's date the hook read (`YYYY-MM-DD`), else `fallback`."
  def parse_date(value, fallback) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _error -> fallback
    end
  end

  def parse_date(_value, fallback), do: fallback

  # ---- Where the reader stands

  @doc """
  Where a plan stands on `today`: `:none` (no plan), `:completed` (the
  Act made; the tab offers the feasts again, as the app's does),
  `{:scheduled, start}` before Day 1, else `{:day, n}`, today's day, held
  at 34 once the 33 days are past.
  """
  def status(nil, _today), do: :none
  def status(%{completed_at: completed}, _today) when is_binary(completed), do: :completed

  def status(%{start: start}, today) do
    case Date.compare(start, today) do
      :gt -> {:scheduled, start}
      _ -> {:day, current_day(start, today)}
    end
  end

  @doc "Today's day of a consecration begun on `start`: from 1, held at 34."
  def current_day(start, today), do: min(max(Date.diff(today, start), 0) + 1, @last_day)

  @doc "Today's day, or nil when there is no plan under way."
  def today_day(plan, today) do
    case status(plan, today) do
      {:day, n} -> n
      _other -> nil
    end
  end

  @doc "Consecration Day of a consecration begun on `start`."
  def consecration_date(start), do: Date.add(start, @last_day - 1)

  @doc "Whole days from `today` to `date`; negative once it has passed."
  def days_until(date, today), do: Date.diff(date, today)

  # ---- The feasts

  @doc """
  Every feast's next preparation that can still begin on its Day 1, the
  soonest first: `%{feast:, start:, feast_date:}`, with Day 1 thirty-three
  days before the feast. This year's while its Day 1 is today or later,
  else next year's, so each runs its full 33 days and ends on its feast.
  """
  def preparations(feasts, today) do
    feasts
    |> Enum.flat_map(fn feast ->
      case preparation(feast, today) do
        nil -> []
        prep -> [prep]
      end
    end)
    |> Enum.sort_by(& &1.start, Date)
  end

  @doc "One feast's next preparation from `today`, or nil."
  def preparation(feast, today) do
    Enum.find_value([today.year, today.year + 1], fn year ->
      with {:ok, feast_date} <- Date.new(year, feast.month, feast.day),
           start = Date.add(feast_date, -(@last_day - 1)),
           true <- Date.compare(start, today) != :lt do
        %{feast: feast, start: start, feast_date: feast_date}
      else
        _ -> nil
      end
    end)
  end

  @doc "The feast a preparation begun on `start` ends on, if it ends on one."
  def feast_ending(feasts, start) do
    finish = consecration_date(start)
    Enum.find(feasts, &(&1.month == finish.month and &1.day == finish.day))
  end

  @doc "Day 1 of a consecration begun today at `day` (Start at any day)."
  def start_at(day, today) when day in 1..33, do: Date.add(today, -(day - 1))

  @doc "A day from Start at any day's chooser, held to 1 to 33; anything else is 1."
  def any_day(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n |> max(1) |> min(33)
      _other -> 1
    end
  end

  def any_day(value) when is_integer(value), do: value |> max(1) |> min(33)
  def any_day(_value), do: 1

  # ---- Words for dates, as the app's

  @doc "\"Saturday, November 21\", or \"November 21\"; the year only when it is not this one."
  def long_date(date, today, weekday? \\ true) do
    format =
      case {weekday?, date.year == today.year} do
        {true, true} -> "%A, %B %-d"
        {true, false} -> "%A, %B %-d, %Y"
        {false, true} -> "%B %-d"
        {false, false} -> "%B %-d, %Y"
      end

    Calendar.strftime(date, format)
  end

  @doc "\"Nov 21\"; the year only when it is not this one."
  def short_date(date, today) do
    if date.year == today.year,
      do: Calendar.strftime(date, "%b %-d"),
      else: Calendar.strftime(date, "%b %-d, %Y")
  end

  @doc "\"November 21, 2026\", as the app's long date style."
  def full_date(date), do: Calendar.strftime(date, "%B %-d, %Y")

  @doc "\"in 12 days\", \"tomorrow\", \"today\"."
  def countdown(days) when days <= 0, do: "today"
  def countdown(1), do: "tomorrow"
  def countdown(days), do: "in #{days} days"

  @doc "\"Begin today\", or \"Begin on October 19\"."
  def begin_title(%{start: start}, today) do
    if Date.compare(start, today) == :gt,
      do: "Begin on #{long_date(start, today, false)}",
      else: "Begin today"
  end
end
