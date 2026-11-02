defmodule LumenViaeWeb.Live.Hours.Index do
  @moduledoc """
  `/hours` and `/hours/:date`: Hours of Prayer, the Divine Office's
  landing as the iOS app opens it (`DivineOfficeView`). The page has one
  purpose, to get the reader into the hour that is current: that hour's
  painting at the head with NOW and when it lapses over its name, and one
  gold Pray. The day's feast and its class in plain words follow, then
  the eight hours on a strand of light in a breviary's three groups, each
  bead the colour of its time of day, and the credit.

  `/hours` is today, the visitor's (the `UserTimezone` hook's offset, the
  server's until it connects). `/hours/:date` is another day, reached from
  the month's calendar: its date stands where NOW stands, and the hour the
  clock gives is offered for it. A date that is not one, or that the Office
  does not serve, is a 404.

  The hours need nothing fetched. Only the day's feast travels, through
  `LumenViae.Office.fetch_day/2` and its cache, after the page is shown
  (`start_async`); when it cannot be reached the page says so quietly with
  a Try again, and every hour stays a link. iOS names the day in English
  and gives its vestment colour from the Missal (Missale Meum); this site
  makes no third-party call, so the feast is the Office's own Latin title
  and there is no colour.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Office
  alias LumenViaeWeb.Live.Hours.{CanonicalHours, DayRank}
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Prayers.Painting

  @description "Hours of Prayer: the traditional Divine Office of the Roman Breviary for today, the hour now and all eight hours of the day, in Latin and English."

  @impl true
  def mount(params, _session, socket) do
    now = CanonicalHours.server_now()

    {date, path, title} =
      case params do
        %{"date" => value} ->
          date = parse_date!(value)

          {date, CanonicalHours.day_path(date),
           "Hours of Prayer, " <> CanonicalHours.long_date(date)}

        _today ->
          {NaiveDateTime.to_date(now), "/hours", "Hours of Prayer"}
      end

    {:ok,
     socket
     |> PageMeta.put(path,
       title: title,
       description: @description,
       trail: trail(params, path, title)
     )
     |> assign(:fixed_date?, Map.has_key?(params, "date"))
     |> assign(:groups, CanonicalHours.groups())
     |> assign(:credit, CanonicalHours.credit())
     |> assign(:date, date)
     |> assign_clock(now)
     |> load_day()}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case CanonicalHours.local_now(offset) do
      {:ok, now} ->
        today = NaiveDateTime.to_date(now)
        socket = assign_clock(socket, now)

        if socket.assigns.fixed_date? or today == socket.assigns.date do
          {:noreply, socket}
        else
          {:noreply, socket |> assign(:date, today) |> assign_clock(now) |> load_day()}
        end

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  def handle_event("retry", _params, socket), do: {:noreply, load_day(socket)}

  @impl true
  def handle_async(:day, {:ok, {:ok, day}}, socket) do
    if day.date == socket.assigns.date,
      do: {:noreply, assign(socket, day: day, day_state: :ready)},
      else: {:noreply, socket}
  end

  def handle_async(:day, _failed, socket), do: {:noreply, assign(socket, :day_state, :failed)}

  # The hour now, and whether the page's day is the visitor's today.
  defp assign_clock(socket, now) do
    present = CanonicalHours.present(now.hour)

    socket
    |> assign(:present, present)
    |> assign(:today?, NaiveDateTime.to_date(now) == socket.assigns.date)
    |> assign(:lapses, CanonicalHours.lapses(present))
  end

  defp load_day(socket) do
    date = Date.to_iso8601(socket.assigns.date)
    socket = assign(socket, day: nil, day_state: :loading)

    if connected?(socket),
      do: start_async(socket, :day, fn -> Office.fetch_day(date) end),
      else: socket
  end

  defp parse_date!(value) do
    case CanonicalHours.parse_date(value) do
      {:ok, date} -> date
      :error -> raise LumenViaeWeb.NotFoundError, message: "no office for #{inspect(value)}"
    end
  end

  defp trail(%{"date" => _}, path, title),
    do: [{"Hours of Prayer", "/hours"}, {title, path}]

  defp trail(_params, path, title), do: [{title, path}]

  @doc false
  def class_line(day), do: DayRank.plain_for(day)
end
