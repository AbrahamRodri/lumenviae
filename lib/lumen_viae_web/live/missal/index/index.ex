defmodule LumenViaeWeb.Live.Missal.Index do
  @moduledoc """
  `/missal` and `/missal/:date`: the Daily Missal, the iOS app's
  `DailyMissalView`, a day's 1962 propers from Missale Meum. The plate
  names the feast and what else is remembered, with the day's arrows
  around its vestment colour (a dot) and its class in plain words, and
  the date (the app's date pill) opening the month's calendar; then the
  language, a choice where the day has several Masses (Christmas, All
  Souls), About This Day where Missale Meum says something of it, the
  parts of the Mass to jump between, and the texts. The Mass closes on
  THE MASS IS ENDED, the way to the Order of Mass, and the credit.

  `/missal` is today, the visitor's (the `UserTimezone` hook's offset).
  Until it comes the plate is an empty frame of its size and nothing is
  fetched, so a visitor in an American evening is never shown tomorrow's
  Mass in UTC. `/missal/:date` is another day: Return to today stands
  under its plate once the visitor's today is known to be another day.

  The link carries the choices, a default never written: `?lang=latin`
  or `?lang=both` (English otherwise), `?mass=2` for the second Mass of a
  day that has several. A date that is not one, or that the Missal does
  not serve, is a 404.

  The texts come through `LumenViae.Office.fetch_mass/1`, fetched by the
  server and cached there, after the page is shown (`start_async`); when
  Missale Meum cannot be reached the plate says so with a Try again,
  which asks again only after a failure.

  As the Android app, the page sets the day's own texts and leaves the
  fixed parts to the Order of Mass's page; the app's "With the
  Ordinary" reading, its text size and posture settings, the first-open
  layout question and the offline week are left out (the width decides
  side by side; posture is always shown).
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Office
  alias LumenViaeWeb.Live.Hours.{CanonicalHours, PartsRail}
  alias LumenViaeWeb.Live.Missal.{Days, MissalText}
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Missal.Section

  @description "Today's Mass in the traditional Latin Mass (the 1962 Missal): the day's feast, its propers in Latin and English, and the Order of Mass."

  @impl true
  def mount(params, _session, socket) do
    fixed_date? = socket.assigns.live_action == :day

    {date, path, title} =
      if fixed_date? do
        date = parse_date!(params["date"])
        {date, "/missal/" <> Date.to_iso8601(date), "The Mass, " <> Days.long_date(date)}
      else
        {NaiveDateTime.to_date(CanonicalHours.server_now()), "/missal", "The Mass · Daily Missal"}
      end

    socket =
      socket
      |> PageMeta.put(path,
        title: title,
        description: @description,
        image: PageMeta.named_image("topic_holy_mass"),
        trail: trail(fixed_date?, path, title)
      )
      |> assign(:fixed_date?, fixed_date?)
      |> assign(:date, date)
      |> assign(:today, nil)
      |> assign(:clock_known?, fixed_date?)
      |> assign(masses: nil, mass: nil, sections: [], state: :waiting)
      |> assign(language: "english", mass_number: 1, languages: MissalText.languages())

    {:ok, if(fixed_date?, do: load(socket), else: socket)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:language, MissalText.language(params["lang"]))
     |> assign(:mass_number, mass_number(params["mass"]))
     |> assign_mass()}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case CanonicalHours.local_now(offset) do
      {:ok, now} -> {:noreply, set_today(socket, NaiveDateTime.to_date(now))}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  # Only after a failure: a Try again can never cut a fetch short or start
  # another while one is on its way.
  def handle_event("retry", _params, %{assigns: %{state: :failed}} = socket),
    do: {:noreply, load(socket)}

  def handle_event("retry", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_async(:mass, {:ok, {date, {:ok, masses}}}, socket) do
    if date == socket.assigns.date,
      do: {:noreply, socket |> assign(masses: masses, state: :ready) |> assign_mass()},
      else: {:noreply, socket}
  end

  def handle_async(:mass, {:ok, {date, _failed}}, socket) do
    if date == socket.assigns.date,
      do: {:noreply, assign(socket, :state, :failed)},
      else: {:noreply, socket}
  end

  def handle_async(:mass, _crashed, socket), do: {:noreply, assign(socket, :state, :failed)}

  # The visitor's today: today's page moves to it and fetches its Mass the
  # first time, or when the date has turned.
  defp set_today(%{assigns: %{fixed_date?: true}} = socket, today),
    do: assign(socket, :today, today)

  defp set_today(socket, today) do
    socket = assign(socket, today: today, clock_known?: true)

    if today == socket.assigns.date and socket.assigns.state != :waiting,
      do: socket,
      else: socket |> assign(:date, today) |> load()
  end

  # The page waits on the fetch, never runs it: `Office.fetch_mass/1`
  # hands it to a process of the Office's, so leaving the page never stops
  # it. A wait for an earlier date is let go.
  defp load(socket) do
    date = socket.assigns.date
    socket = assign(socket, masses: nil, mass: nil, sections: [], state: :loading)

    if connected?(socket) do
      socket
      |> cancel_async(:mass)
      |> start_async(:mass, fn -> {date, Office.fetch_mass(date)} end)
    else
      socket
    end
  end

  defp assign_mass(%{assigns: %{masses: masses}} = socket)
       when is_list(masses) and masses != [] do
    number = min(socket.assigns.mass_number, length(masses))
    mass = Enum.at(masses, number - 1)

    socket
    |> assign(:mass, mass)
    |> assign(:sections, MissalText.day_sections(mass.sections, socket.assigns.language))
  end

  defp assign_mass(socket), do: assign(socket, mass: nil, sections: [])

  defp mass_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number in 1..9 -> number
      _other -> 1
    end
  end

  defp mass_number(_value), do: 1

  defp parse_date!(value) do
    case Days.parse_date(value) do
      {:ok, date} -> date
      :error -> raise LumenViaeWeb.NotFoundError, message: "no Mass for #{inspect(value)}"
    end
  end

  defp trail(true, path, title), do: [{"The Mass", "/missal"}, {title, path}]
  defp trail(false, path, _title), do: [{"The Mass", path}]

  @doc false
  def today?(%{today: today, date: date}), do: today == date

  @doc false
  def about_paragraphs(text),
    do: text |> String.split(~r/\n\s*\n|\n/u) |> Enum.reject(&(String.trim(&1) == ""))

  @doc false
  # This page's link with another language or Mass: today's keeps its
  # address, another day its own.
  def page_path(date, true, language, mass), do: Days.day_path(date, language, mass)
  def page_path(_date, false, language, mass), do: Days.today_path(language, mass)
end
