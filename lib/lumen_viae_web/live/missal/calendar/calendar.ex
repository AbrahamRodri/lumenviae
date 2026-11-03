defmodule LumenViaeWeb.Live.Missal.Calendar do
  @moduledoc """
  `/missal/calendar/:year/:month`: a month of the 1962 calendar, as the
  iOS app's date pill opens it (`MissalCalendarSheet` on
  `LiturgicalMonthGrid`): the month with arrows either side, the weeks
  from Sunday, and each day carrying its vestment colour as a small dot
  under its number. Each day opens its Mass. A wide screen has room for
  each day's title in its cell, as the Hours of Prayer's month does (the
  same grid), and a phone shows today's beneath the grid.

  The year is `LumenViae.Office.fetch_missal_calendar/1`, fetched by the
  server and cached there, after the page is shown; when it cannot be
  reached the grid still links every day and says so, with a Try again
  (after a failure only). Today is marked once the `UserTimezone` hook
  gives the visitor's date. The app's offline row (Save the month) has no
  place on a website and is left out. A month that is not one, or that
  the Missal does not serve, is a 404.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Office
  alias LumenViaeWeb.Live.Hours.CanonicalHours
  alias LumenViaeWeb.Live.Missal.Days
  alias LumenViaeWeb.PageMeta

  @weekdays ~w(S M T W T F S)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:weekdays, @weekdays)
     |> assign(today: nil, loaded_year: nil, days: %{}, state: :idle)}
  end

  @impl true
  def handle_params(%{"year" => year, "month" => month}, _uri, socket) do
    {year, month} =
      case Days.parse_month(year, month) do
        {:ok, ym} -> ym
        :error -> raise LumenViaeWeb.NotFoundError, message: "no calendar for #{year}/#{month}"
      end

    title = Days.month_title(year, month)
    path = Days.calendar_path(year, month)

    socket =
      socket
      |> PageMeta.put(path,
        title: "The Mass, #{title}",
        description:
          "The 1962 calendar for #{title}: each day's feast and vestment colour, and its Mass.",
        trail: [{"The Mass", "/missal"}, {title, path}]
      )
      |> assign(year: year, month: month, title: title)
      |> assign(:cells, cells(year, month))
      |> assign(:previous, neighbour(year, month, -1))
      |> assign(:next, neighbour(year, month, 1))

    # The calendar comes a year at a time: a month of the same year needs
    # nothing fetched again.
    if socket.assigns.loaded_year == year and socket.assigns.state == :ready,
      do: {:noreply, socket},
      else: {:noreply, load(socket)}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case CanonicalHours.local_now(offset) do
      {:ok, now} -> {:noreply, assign(socket, :today, NaiveDateTime.to_date(now))}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  def handle_event("retry", _params, %{assigns: %{state: :failed}} = socket),
    do: {:noreply, load(socket)}

  def handle_event("retry", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_async(:year, {:ok, {year, {:ok, days}}}, socket) do
    if year == socket.assigns.year,
      do: {:noreply, assign(socket, days: days, state: :ready, loaded_year: year)},
      else: {:noreply, socket}
  end

  def handle_async(:year, {:ok, {year, _failed}}, socket) do
    if year == socket.assigns.year,
      do: {:noreply, assign(socket, :state, :failed)},
      else: {:noreply, socket}
  end

  def handle_async(:year, _crashed, socket), do: {:noreply, assign(socket, :state, :failed)}

  defp load(socket) do
    year = socket.assigns.year
    socket = assign(socket, days: %{}, state: :loading, loaded_year: nil)

    if connected?(socket) do
      socket
      |> cancel_async(:year)
      |> start_async(:year, fn -> {year, Office.fetch_missal_calendar(year)} end)
    else
      socket
    end
  end

  # The month padded to whole weeks from Sunday: nil for a blank cell.
  defp cells(year, month) do
    first = Date.new!(year, month, 1)
    leading = rem(Date.day_of_week(first), 7)
    dates = Enum.map(0..(Date.days_in_month(first) - 1), &Date.add(first, &1))
    padded = List.duplicate(nil, leading) ++ dates
    padded ++ List.duplicate(nil, rem(7 - rem(length(padded), 7), 7))
  end

  defp neighbour(year, month, step) do
    date = Date.new!(year, month, 1) |> Date.shift(month: step)

    case Days.parse_month(to_string(date.year), to_string(date.month)) do
      {:ok, _} -> Days.calendar_path(date)
      :error -> nil
    end
  end

  @doc false
  def spoken(date, nil), do: Days.long_date(date)

  def spoken(date, day) do
    [Days.long_date(date), day.title, Days.vestment(day) && Days.vestment(day).plain]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(". ")
  end

  @doc false
  def today_shown?(%Date{year: year, month: month} = today, year, month, days),
    do: Map.has_key?(days, today)

  def today_shown?(_today, _year, _month, _days), do: false
end
