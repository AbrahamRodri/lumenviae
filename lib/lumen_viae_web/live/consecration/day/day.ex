defmodule LumenViaeWeb.Live.Consecration.Day do
  @moduledoc """
  `/consecration/days/:n`: one day of the 33, from 1 to 34 (Consecration
  Day), as the app's `ConsecrationDayOverviewView` draws it: the phase's
  painting in the arch with the day's badge, title and Pray; the feast
  the reader's 33 days count toward; the day's prayers (English, Latin or
  Both, `?lang=`), its readings and its question to sit with; the
  journey, the five stages as one road with their days (today and the
  days prayed marked from this browser's plan); the book behind the
  consecration; and Restart.

  `?step=` walks the day as `ConsecrationDayFlowView` does, a page a step
  (counted from 1): each prayer of the phase, set by the Prayer Book's
  `PrayerText` with the chant it is sung to where the Chant Library has
  one (the `ChantGuest` hook), then each reading. Amen on the last keeps
  the day as prayed in this browser (the `ConsecrationPlan` hook, only
  under a plan, and only on its day or after) and returns to today's day,
  or on Consecration Day, when it is today or without a plan, goes on to
  the Act made, `/consecration/act`. A day ahead stays open to read; its
  Amen keeps nothing and returns to it. The app's reflection, written in its
  journal, is not on the website.

  Every day is open to anyone, with or without a plan. A day that is not
  one (`0`, `35`, `2.5`, a word) is a 404; a `step` past either end is the
  nearest, and anything else the first.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Consecration.{Days, Plan, State}
  alias LumenViaeWeb.Live.Prayers.PrayerText
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Consecration.Parts
  import LumenViaeWeb.Live.Consecration.Day.Overview
  import LumenViaeWeb.Live.Consecration.Day.Flow

  @impl true
  def mount(%{"n" => n}, _session, socket) do
    number =
      Days.day_number(n) ||
        raise LumenViaeWeb.NotFoundError,
          message: "unknown day of the Consecration: #{inspect(n)}"

    doc = Days.load(socket.assigns.current_admin, chants: true)
    day = Days.day(doc, number) || raise LumenViaeWeb.NotFoundError, message: "no day #{number}"
    phase = Days.phase(doc, day)

    {:ok,
     socket
     |> PageMeta.put(Days.day_path(number),
       title: page_title(number, day),
       description: description(number, day, phase),
       image: PageMeta.named_image(phase.painting),
       trail: [{"Consecration", Days.path()}, {Days.badge(number), Days.day_path(number)}]
     )
     |> assign(:doc, doc)
     |> assign(:number, number)
     |> assign(:day, day)
     |> assign(:phase, phase)
     |> assign(:prayers, Days.prayers(doc, phase))
     |> assign(:readings, Days.readings(day))
     |> assign(:steps, Days.steps(doc, day))
     |> assign(:shown_phase, phase)
     |> assign(step: nil, entry: nil, count: 0, previous: nil, next: nil)
     |> assign(shown_language: "english", stanzas: [], chant: nil)
     |> State.init()
     |> assign_plan()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    language = PrayerText.language(params["lang"])

    socket =
      if Map.has_key?(params, "step") do
        assign_step(socket, Days.step(params["step"], length(socket.assigns.steps)))
      else
        assign(socket, :step, nil)
      end

    {:noreply, assign(socket, :language, language) |> assign_flow_language()}
  end

  # Restart from a day's page returns to the Consecration, which opens on
  # the feast chooser for a returning reader, as the app's tab does.
  @impl true
  def handle_event("consecration_state", %{"restarted" => true}, socket),
    do: {:noreply, push_navigate(socket, to: Days.path())}

  def handle_event("consecration_state", params, socket) do
    {:noreply,
     socket
     |> State.put(params, socket.assigns.doc.feasts)
     |> assign_plan()}
  end

  def handle_event("show_phase", %{"id" => id}, socket) do
    case Days.phase_by_id(socket.assigns.doc, id) do
      nil -> {:noreply, socket}
      phase -> {:noreply, assign(socket, :shown_phase, phase)}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp assign_plan(socket) do
    %{plan: plan, today: today, number: number, done: done} = socket.assigns
    today_day = Plan.today_day(plan, today)

    socket
    |> assign(:today_day, today_day)
    |> assign(:today?, today_day == number)
    |> assign(:done?, number in done)
    |> assign(:feast, plan && Plan.feast_ending(socket.assigns.doc.feasts, plan.start))
    |> assign(:until_feast, plan && Plan.days_until(Plan.consecration_date(plan.start), today))
  end

  defp assign_step(socket, step) do
    steps = socket.assigns.steps

    socket
    |> assign(:step, step)
    |> assign(:entry, Enum.at(steps, step - 1))
    |> assign(:count, length(steps))
    |> assign(:previous, if(step > 1, do: Enum.at(steps, step - 2)))
    |> assign(:next, Enum.at(steps, step))
  end

  # A prayer with no Latin is set in English, and keeps the choice for the
  # next, as the Prayer Book's pray-along does.
  defp assign_flow_language(%{assigns: %{step: nil}} = socket), do: socket

  defp assign_flow_language(socket) do
    case socket.assigns.entry do
      {:prayer, prayer} ->
        shown = if prayer.latin, do: socket.assigns.language, else: "english"

        socket
        |> assign(:shown_language, shown)
        |> assign(:stanzas, PrayerText.stanzas(prayer.english, prayer.latin, shown))
        |> assign(:chant, Days.chant(socket.assigns.doc, prayer))

      {:reading, _reading} ->
        socket |> assign(:shown_language, "english") |> assign(:chant, nil)

      nil ->
        socket |> assign(:shown_language, "english") |> assign(stanzas: [], chant: nil)
    end
  end

  defp page_title(34, _day), do: "Consecration Day, Consecration to Mary"
  defp page_title(n, day), do: "Day #{n}: #{day.title}, Consecration to Mary"

  defp description(n, day, phase) do
    readings = day |> Days.readings() |> Enum.map_join(", ", & &1.title)

    "#{Days.short_badge(n)} of the Consecration to Jesus through Mary, #{phase.subtitle}: #{day.title}. Its prayers, and #{readings}."
  end
end
