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

  The Mass is read whole by default, as the app reads it ("With the
  Ordinary"): the Order of Mass's prayers let into their places among the
  day's own texts (`LumenViaeWeb.Live.Missal.Ordinary`), the Order of
  Mass fetched alongside the day (`LumenViae.Office.fetch_order_of_mass/0`,
  cached as its own page's is). The app's Contents choice, Today's texts
  only or Whole Mass, and its Sung Mass switch, here Spoken or Sung, stand
  under the language; they are this browser's own (the `MissalReading`
  hook keeps them in localStorage, never on the server). Until the Order
  of Mass has come the day waits for it; without it the day's texts stand
  alone, as the app's do.

  The app's text size and posture settings, the first-open layout question
  and the offline week are left out (the width decides side by side;
  posture is always shown).
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Office
  alias LumenViaeWeb.Live.Hours.{CanonicalHours, PartsRail}
  alias LumenViaeWeb.Live.Missal.{Days, MissalText, Ordinary}
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
      |> assign(whole?: true, sung?: false, ordo: nil, ordo_state: :idle)

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

  # Today's texts only or the Whole Mass, and Spoken or Sung: chosen here,
  # kept by this browser.
  def handle_event("set_contents", %{"contents" => contents}, socket)
      when contents in ["propers", "whole"] do
    {:noreply,
     socket
     |> assign(:whole?, contents == "whole")
     |> reading_changed()
     |> store_reading()}
  end

  def handle_event("set_sung", %{"sung" => sung}, socket) when sung in ["true", "false"] do
    {:noreply,
     socket
     |> assign(:sung?, sung == "true")
     |> reading_changed()
     |> store_reading()}
  end

  # The MissalReading hook hands back what this browser chose before.
  def handle_event("restore_reading", params, socket) do
    whole? =
      case params["contents"] do
        "propers" -> false
        "whole" -> true
        _other -> socket.assigns.whole?
      end

    sung? = if is_boolean(params["sung"]), do: params["sung"], else: socket.assigns.sung?

    {:noreply, socket |> assign(whole?: whole?, sung?: sung?) |> reading_changed()}
  end

  def handle_event(event, _params, socket)
      when event in ["set_contents", "set_sung"],
      do: {:noreply, socket}

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

  def handle_async(:ordo, {:ok, {:ok, ordo}}, socket),
    do: {:noreply, socket |> assign(ordo: ordo, ordo_state: :ready) |> assign_mass()}

  # Without the Order of Mass the day's texts stand alone, as the app's do.
  def handle_async(:ordo, _failed, socket),
    do: {:noreply, socket |> assign(:ordo_state, :failed) |> assign_mass()}

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
      |> load_ordo()
    else
      socket
    end
  end

  # The Order of Mass, once, and again only after a failure, when the
  # Whole Mass is read.
  defp load_ordo(%{assigns: %{whole?: true, ordo_state: state}} = socket)
       when state in [:idle, :failed] do
    if connected?(socket),
      do:
        socket
        |> assign(:ordo_state, :loading)
        |> start_async(:ordo, &Office.fetch_order_of_mass/0),
      else: socket
  end

  defp load_ordo(socket), do: socket

  defp reading_changed(socket) do
    socket = if socket.assigns.state == :waiting, do: socket, else: load_ordo(socket)
    assign_mass(socket)
  end

  defp store_reading(socket) do
    push_event(socket, "store_missal_reading", %{
      contents: if(socket.assigns.whole?, do: "whole", else: "propers"),
      sung: socket.assigns.sung?
    })
  end

  defp assign_mass(%{assigns: %{masses: masses}} = socket)
       when is_list(masses) and masses != [] do
    number = min(socket.assigns.mass_number, length(masses))
    mass = Enum.at(masses, number - 1)

    socket
    |> assign(:mass, mass)
    |> assign(:sections, sections(socket.assigns, mass))
  end

  defp assign_mass(socket), do: assign(socket, mass: nil, sections: [])

  # The Whole Mass waits for the Order of Mass, so the page is not
  # rebuilt under the reader when it comes.
  defp sections(%{whole?: true, ordo_state: :loading}, _mass), do: []

  defp sections(%{whole?: true} = assigns, mass) do
    mass.sections
    |> Ordinary.weave(assigns.ordo, mass, date: assigns.date, sung?: assigns.sung?)
    |> MissalText.mass_sections(assigns.language)
  end

  defp sections(assigns, mass), do: MissalText.day_sections(mass.sections, assigns.language)

  @doc false
  # The day is in hand and the Whole Mass waits on the Order of Mass.
  def ordo_waiting?(%{mass: mass, whole?: whole?, ordo_state: state}),
    do: mass != nil and whole? and state == :loading

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
