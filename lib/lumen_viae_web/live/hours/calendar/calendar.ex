defmodule LumenViaeWeb.Live.Hours.Calendar do
  @moduledoc """
  `/hours/calendar/:year/:month`: one month of the breviary's calendar, as
  the iOS app's calendar sheet draws it (`OfficeCalendarSheet` on
  `LiturgicalMonthGrid`): the month with arrows either side, the weeks
  from Sunday, and each day marked by its class, a gold mark brighter for
  the greater feasts and none on a feria, so a month reads at a glance
  the way a finger down a printed ribbon does. Each day opens its Hours of
  Prayer. A wide screen has room for each day's own title in its cell,
  which the app shows only for the day under the finger; a phone shows
  today's beneath the grid, as the app does.

  The month is `LumenViae.Office.fetch_calendar/3`, through its cache,
  fetched after the page is shown; when it cannot be reached the grid
  still links every day and says so, with a Try again. The app's offline
  row (Save the month) has no place on a website and is left out. Today
  is marked once the `UserTimezone` hook gives the visitor's date, never
  the server's. A fetch still on its way when the arrows move on is
  cancelled. A month
  that is not one, or that the Office does not serve, is a 404.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Office
  alias LumenViaeWeb.Live.Hours.{CanonicalHours, DayRank}
  alias LumenViaeWeb.PageMeta

  @weekdays ~w(S M T W T F S)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:weekdays, @weekdays)
     |> assign(:today, nil)}
  end

  @impl true
  def handle_params(%{"year" => year, "month" => month}, _uri, socket) do
    {year, month} =
      case CanonicalHours.parse_month(year, month) do
        {:ok, ym} -> ym
        :error -> raise LumenViaeWeb.NotFoundError, message: "no calendar for #{year}/#{month}"
      end

    title = CanonicalHours.month_title(year, month)
    path = CanonicalHours.calendar_path(year, month)

    {:noreply,
     socket
     |> PageMeta.put(path,
       title: "Hours of Prayer, #{title}",
       description:
         "The traditional Roman calendar for #{title}: each day's feast and class, and its Hours of Prayer.",
       trail: [{"Hours of Prayer", "/hours"}, {title, path}]
     )
     |> assign(year: year, month: month, title: title)
     |> assign(:cells, cells(year, month))
     |> assign(:previous, neighbour(year, month, -1))
     |> assign(:next, neighbour(year, month, 1))
     |> load()}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case CanonicalHours.local_now(offset) do
      {:ok, now} -> {:noreply, assign(socket, :today, NaiveDateTime.to_date(now))}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  def handle_event("retry", _params, socket), do: {:noreply, load(socket)}

  @impl true
  def handle_async(:month, {:ok, {:ok, %{year: year, month: month, days: days}}}, socket) do
    if {year, month} == {socket.assigns.year, socket.assigns.month} do
      {:noreply, assign(socket, days: Map.new(days, &{&1.date, &1}), state: :ready)}
    else
      {:noreply, socket}
    end
  end

  def handle_async(:month, _failed, socket), do: {:noreply, assign(socket, :state, :failed)}

  defp load(socket) do
    %{year: year, month: month} = socket.assigns
    socket = assign(socket, days: %{}, state: :loading)

    if connected?(socket) do
      socket
      |> cancel_async(:month)
      |> start_async(:month, fn -> Office.fetch_calendar(year, month) end)
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

    case CanonicalHours.parse_month(to_string(date.year), to_string(date.month)) do
      {:ok, _} -> CanonicalHours.calendar_path(date)
      :error -> nil
    end
  end

  @doc false
  # The calendar's own title for a day: its feast, or the season it falls
  # under, or Weekday; nil while the month is still on its way.
  def day_title(nil), do: nil

  def day_title(day) do
    cond do
      day.celebration && present?(day.celebration.title) -> day.celebration.title
      day.detail && present?(day.detail.text) -> day.detail.text
      true -> "Weekday"
    end
  end

  defp present?(text), do: is_binary(text) and String.trim(text) != ""

  @doc false
  # The phone's line for today, once the visitor's date is known and its
  # day has come.
  def today_shown?(%Date{year: year, month: month} = today, year, month, days),
    do: Map.has_key?(days, today)

  def today_shown?(_today, _year, _month, _days), do: false

  @doc false
  def mark(nil), do: nil
  def mark(day), do: DayRank.mark(day.celebration && day.celebration.rank)

  @doc false
  def spoken(date, day) do
    case day_title(day) do
      nil -> CanonicalHours.long_date(date)
      title -> "#{CanonicalHours.long_date(date)}. #{title}"
    end
  end
end
