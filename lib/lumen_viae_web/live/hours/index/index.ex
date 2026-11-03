defmodule LumenViaeWeb.Live.Hours.Index do
  @moduledoc """
  `/hours` and `/hours/:date`: Hours of Prayer, the Divine Office's
  landing as the iOS app opens it (`DivineOfficeView`). The page has one
  purpose, to get the reader into the hour that is current: that hour's
  painting at the head with NOW and when it lapses over its name, and one
  gold Pray. The day's feast and its class in plain words follow, then
  the eight hours on a strand of light in a breviary's three groups, each
  bead the colour of its time of day, and the credit.

  `/hours` is today, the visitor's: the `UserTimezone` hook's offset.
  Until it comes, the hour now and the date stand as an empty frame of
  their size and the day is not fetched, so a visitor in an American
  evening is never shown tomorrow in UTC (as `/prayers` waits for its Now
  card). The strand links the server's date meanwhile, which serves a
  page without JavaScript. `/hours/:date` is another day, reached from the
  month's calendar: its date stands where NOW stands, and the hour the
  clock gives is offered for it once the clock is known. A date that is
  not one, or that the Office does not serve, is a 404; a `?date=` on
  `/hours` is ignored.

  The hours need nothing fetched. Only the day's feast travels, through
  `LumenViae.Office.fetch_day/2` and its cache, after the page is shown
  (`start_async`); when it cannot be reached the page says so quietly with
  a Try again, and every hour stays a link. As iOS does, the day is
  named in English with its vestment colour from the Missal
  (`LumenViae.Office.fetch_mass/1`, fetched by the server from Missale
  Meum) once it arrives; until then, or when Missale Meum cannot be
  reached, the feast is the Office's own Latin title and there is no
  colour. The Missal's name stands even when the Office's day could not
  be reached, as on iOS.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Office
  alias LumenViaeWeb.Live.Hours.{CanonicalHours, DayRank}
  alias LumenViaeWeb.Live.Missal.Days, as: MissalDays
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Prayers.Painting

  @description "Hours of Prayer: the traditional Divine Office of the Roman Breviary for today, the hour now and all eight hours of the day, in Latin and English."

  @impl true
  def mount(params, _session, socket) do
    fixed_date? = socket.assigns.live_action == :day

    {date, path, title} =
      if fixed_date? do
        date = parse_date!(params["date"])

        {date, CanonicalHours.day_path(date),
         "Hours of Prayer, " <> CanonicalHours.long_date(date)}
      else
        {NaiveDateTime.to_date(CanonicalHours.server_now()), "/hours", "Hours of Prayer"}
      end

    socket =
      socket
      |> PageMeta.put(path,
        title: title,
        description: @description,
        image: preview_image(),
        trail: trail(fixed_date?, path, title)
      )
      |> assign(:fixed_date?, fixed_date?)
      |> assign(:groups, CanonicalHours.groups())
      |> assign(:credit, CanonicalHours.credit())
      |> assign(:date, date)
      |> assign(clock_known?: false, present: nil, today?: false, lapses: nil)
      |> assign(day: nil, day_state: :waiting, missal_day: nil)

    {:ok, if(fixed_date?, do: load_day(socket), else: socket)}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case CanonicalHours.local_now(offset) do
      {:ok, now} -> {:noreply, set_clock(socket, now)}
      :error -> {:noreply, socket}
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

  # The month's data has no such day: nothing to say, and nothing to retry.
  def handle_async(:day, {:ok, {:error, :not_found}}, socket),
    do: {:noreply, assign(socket, day: nil, day_state: :none)}

  def handle_async(:day, _failed, socket), do: {:noreply, assign(socket, :day_state, :failed)}

  # The Missal's name and colour for the day; nothing said when it fails.
  def handle_async(:missal_day, {:ok, {date, {:ok, [mass | _others]}}}, socket) do
    if date == socket.assigns.date,
      do: {:noreply, assign(socket, :missal_day, mass)},
      else: {:noreply, socket}
  end

  def handle_async(:missal_day, _no_mass, socket), do: {:noreply, socket}

  # The visitor's clock: today's page moves to the visitor's date and
  # fetches its day the first time, or when the date has turned.
  defp set_clock(%{assigns: %{fixed_date?: true}} = socket, now), do: assign_clock(socket, now)

  defp set_clock(socket, now) do
    today = NaiveDateTime.to_date(now)

    if today == socket.assigns.date and socket.assigns.day_state != :waiting do
      assign_clock(socket, now)
    else
      socket |> assign(:date, today) |> assign_clock(now) |> load_day()
    end
  end

  # The hour now, and whether the page's day is the visitor's today.
  defp assign_clock(socket, now) do
    present = CanonicalHours.present(now.hour)

    socket
    |> assign(:clock_known?, true)
    |> assign(:present, present)
    |> assign(:today?, NaiveDateTime.to_date(now) == socket.assigns.date)
    |> assign(:lapses, CanonicalHours.lapses(present))
  end

  # A fetch still on its way for an earlier date is cancelled, so quick
  # changes never pile requests on the engine.
  defp load_day(socket) do
    day = socket.assigns.date
    date = Date.to_iso8601(day)
    socket = assign(socket, day: nil, day_state: :loading, missal_day: nil)

    if connected?(socket) do
      socket
      |> cancel_async(:day)
      |> start_async(:day, fn -> Office.fetch_day(date) end)
      |> cancel_async(:missal_day)
      |> start_async(:missal_day, fn -> {day, Office.fetch_mass(day)} end)
    else
      socket
    end
  end

  defp parse_date!(value) do
    case CanonicalHours.parse_date(value) do
      {:ok, date} -> date
      :error -> raise LumenViaeWeb.NotFoundError, message: "no office for #{inspect(value)}"
    end
  end

  # A link preview shows the painting of the hour now on the server's clock:
  # the page's own head waits for the visitor's.
  defp preview_image do
    PageMeta.named_image(CanonicalHours.present(CanonicalHours.server_now().hour).painting)
  end

  defp trail(true, path, title), do: [{"Hours of Prayer", "/hours"}, {title, path}]
  defp trail(false, path, title), do: [{title, path}]

  @doc false
  # "Lesser Feast · White vestments", the colour once the Missal has it,
  # and the class from the Missal too where the Office could not be reached.
  def class_line(day, missal_day \\ nil) do
    [
      DayRank.plain_for(day) || MissalDays.class(missal_day),
      MissalDays.vestment(missal_day) && MissalDays.vestment(missal_day).plain
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      parts -> Enum.join(parts, " · ")
    end
  end
end
