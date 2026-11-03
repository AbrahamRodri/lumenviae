defmodule LumenViaeWeb.Live.Home.Index do
  @moduledoc """
  The home page: the daily Rosary hub.

  Today's mysteries on the visitor's schedule, in the visitor's own
  timezone (the `UserTimezone` hook sends `set_timezone`), with the five
  mysteries and their fruits, the meditation sets for them straight into
  prayer, the set-less forms of the Rosary, and every category as a card.

  The schedule is the traditional one, the server's default, until the
  visitor chooses the modern one (Luminous on Thursday, Joyful on
  Saturday), as the app offers in Settings. The choice is this browser's:
  the `MysterySchedule` hook keeps it in localStorage and sends it back on
  connect, as `UserTimezone` sends the offset.

  The mysteries' names, fruits and paintings come from the database; a
  category whose mysteries are not there yet falls back to the labels
  `LumenViae.Rosary.Categories` gives each position.

  Today's Prayer (`LumenViaeWeb.Live.Home.TodaysPrayer`) follows the
  categories, as on the app's Home: the Consecration from the plan the
  `ConsecrationPlan` hook reads from this browser (`consecration_state`),
  the hour's order, Today's Mass and the Hours of Prayer from the
  browser's clock (the Mass fetched by the server for the visitor's date,
  through `LumenViae.Office.fetch_mass/1`). Each
  row waits as an empty frame until its source has spoken, and while the
  page is open the rows turn on the hour.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.LiturgicalCalendar
  alias LumenViae.Office
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork
  alias LumenViae.Rosary.{Categories, Labels}
  alias LumenViaeWeb.Components.{MysteryPainting, SetPortrait}
  alias LumenViaeWeb.Live.Consecration.Plan
  alias LumenViaeWeb.Live.Home.TodaysPrayer
  alias LumenViaeWeb.PageMeta

  @numerals ~w(I II III IV V VI VII)
  @week_days Enum.zip(1..7, ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday))

  # A browser's offset is at most fourteen hours either side of UTC; the
  # bound is a week so the tests can move "today" by whole days, and
  # anything past it is not an offset at all.
  @max_offset_minutes 7 * 24 * 60

  @description "Pray the Holy Rosary each day with meditations from the saints: today's mysteries, the Scriptural Rosary and guided audio, from the Joyful to the Seven Sorrows."

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_admin

    categories = build_categories(actor)

    meditation_sets = Rosary.list_visible_meditation_set_summaries!(actor: actor)

    {:ok,
     socket
     |> PageMeta.put("/",
       title: "Meditations on the Holy Rosary",
       description: @description,
       json_ld: [PageMeta.website(@description)]
     )
     |> assign(:schedule, LiturgicalCalendar.default_schedule())
     |> assign(:categories, categories)
     |> assign(:meditation_sets, meditation_sets)
     |> assign_today(Date.utc_today())
     # The dead render shows the rows' empty frames, so the documents load
     # only once connected.
     |> assign(:prayer_data, if(connected?(socket), do: TodaysPrayer.load(actor)))
     |> assign(offset: nil, now: nil, turn: nil, mass: nil, mass_date: nil)
     |> assign(plan_known?: false, plan: nil, done: [], plan_today: nil, completed_on: nil)
     |> assign_prayer()}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket)
      when is_integer(offset) and abs(offset) <= @max_offset_minutes do
    # The browser's offset is positive west of UTC (-180 is UTC+3).
    now = local_now(offset)

    {:noreply,
     socket
     |> assign(:offset, offset)
     |> assign_today(NaiveDateTime.to_date(now))
     |> keep_time(now)}
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  # The ConsecrationPlan hook hands over what this browser keeps.
  def handle_event("consecration_state", params, socket) when is_map(params) do
    {:noreply,
     socket
     |> assign(:plan_known?, true)
     |> assign(:plan, Plan.parse(params["plan"], []))
     |> assign(:done, Plan.parse_done(params["done"]))
     |> assign(:plan_today, Plan.parse_date(params["today"], nil))
     |> assign(:completed_on, Plan.parse_date(params["completed_on"], nil))
     |> assign_prayer()}
  end

  # Chosen on the page: applied, and handed to the MysterySchedule hook to
  # keep.
  def handle_event("set_schedule", %{"schedule" => schedule}, socket) do
    case parse_schedule(schedule) do
      nil ->
        {:noreply, socket}

      schedule ->
        {:noreply,
         socket
         |> assign_schedule(schedule)
         |> push_event("store_schedule", %{schedule: Atom.to_string(schedule)})}
    end
  end

  # The MysterySchedule hook hands back the schedule this browser chose.
  def handle_event("restore_schedule", %{"schedule" => schedule}, socket) do
    case parse_schedule(schedule) do
      nil -> {:noreply, socket}
      schedule -> {:noreply, assign_schedule(socket, schedule)}
    end
  end

  def handle_event("restore_schedule", _params, socket), do: {:noreply, socket}

  def handle_event("providence", _params, socket) do
    case socket.assigns.todays_sets do
      [] ->
        {:noreply, socket}

      sets ->
        chosen = Enum.random(sets)
        {:noreply, push_navigate(socket, to: "/meditation-sets/#{chosen.id}/pray")}
    end
  end

  # Today's Mass, for its row; a failure leaves the row as it was.
  @impl true
  def handle_async(:mass, {:ok, {date, {:ok, [mass | _others]}}}, socket) do
    if date == socket.assigns.mass_date,
      do: {:noreply, socket |> assign(:mass, mass) |> assign_prayer()},
      else: {:noreply, socket}
  end

  def handle_async(:mass, _no_mass, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:turn, %{assigns: %{offset: offset}} = socket) when is_integer(offset),
    do: {:noreply, keep_time(socket, local_now(offset))}

  def handle_info(:turn, socket), do: {:noreply, socket}

  # The browser's offset is positive west of UTC (-180 is UTC+3).
  defp local_now(offset),
    do: NaiveDateTime.utc_now() |> NaiveDateTime.add(-offset * 60, :second)

  # Today's Prayer at the visitor's `now`, and a wake on the next hour,
  # a second after it so the clock has passed it.
  defp keep_time(socket, now) do
    if socket.assigns.turn, do: Process.cancel_timer(socket.assigns.turn)
    turn = Process.send_after(self(), :turn, TodaysPrayer.next_turn_in(now) + 1000)

    socket
    |> assign(now: now, turn: turn)
    |> load_mass(NaiveDateTime.to_date(now))
    |> assign_prayer()
  end

  # The visitor's day's Mass, fetched by the server (`Office.fetch_mass/1`
  # runs it where leaving the page never stops it), once a day.
  defp load_mass(%{assigns: %{mass_date: date}} = socket, date), do: socket

  defp load_mass(socket, date) do
    socket = assign(socket, mass: nil, mass_date: date)

    if connected?(socket),
      do: start_async(socket, :mass, fn -> {date, Office.fetch_mass(date)} end),
      else: socket
  end

  # The rows, each waiting until what it says is known: the Consecration
  # for the browser's plan (and a date), the hours for the browser's clock.
  defp assign_prayer(socket) do
    %{prayer_data: data, now: now, plan: plan, done: done} = socket.assigns
    date = if now, do: NaiveDateTime.to_date(now), else: socket.assigns.plan_today

    consecration =
      if socket.assigns.plan_known? and date do
        TodaysPrayer.consecration(data, plan, done, date, socket.assigns.completed_on)
      else
        {:waiting, :consecration}
      end

    hours =
      if now do
        Enum.reject(
          [
            TodaysPrayer.hour_order(data, now),
            TodaysPrayer.mass(socket.assigns.mass),
            TodaysPrayer.office(now)
          ],
          &is_nil/1
        )
      else
        [{:waiting, :hour_order}, {:waiting, :mass}, {:waiting, :office}]
      end

    socket
    |> assign(:prayer_date, now && NaiveDateTime.to_date(now))
    |> assign(:prayer_rows, [consecration | hours])
  end

  defp parse_schedule(schedule) do
    Enum.find(LiturgicalCalendar.schedules(), &(Atom.to_string(&1) == schedule))
  end

  defp assign_schedule(socket, schedule) do
    socket
    |> assign(:schedule, schedule)
    |> assign_today(socket.assigns.today)
  end

  defp assign_today(socket, date) do
    schedule = socket.assigns.schedule
    categories = Enum.map(socket.assigns.categories, &with_days(&1, schedule))
    today_slug = date |> LiturgicalCalendar.recommended_mysteries(schedule) |> Atom.to_string()
    today = Enum.find(categories, &(&1.slug == today_slug))

    todays_sets = Enum.filter(socket.assigns.meditation_sets, &(&1.category == today_slug))

    socket
    |> assign(:categories, categories)
    |> assign(:today, date)
    |> assign(:today_category, today)
    |> assign(:todays_sets, todays_sets)
    |> assign(:week, week(date, schedule))
  end

  defp with_days(category, schedule) do
    days =
      category.slug
      |> String.to_existing_atom()
      |> LiturgicalCalendar.days_in_words(schedule)

    %{category | days: days}
  end

  defp week(date, schedule) do
    today_dow = Date.day_of_week(date)

    Enum.map(@week_days, fn {dow, day_name} ->
      slug =
        date
        |> Date.add(dow - today_dow)
        |> LiturgicalCalendar.recommended_mysteries(schedule)
        |> Atom.to_string()

      %{
        label: String.slice(day_name, 0, 3),
        day_name: day_name,
        mysteries: Categories.devotion_title(slug),
        today?: dow == today_dow
      }
    end)
  end

  defp build_categories(actor) do
    mysteries = Rosary.list_mysteries!(actor: actor)
    seven_sorrows_card = Rosary.get_category_card!("seven_sorrows", actor: actor)

    Enum.map(LiturgicalCalendar.categories(), fn category ->
      slug = Atom.to_string(category)
      count = Categories.mystery_count(slug)

      in_category =
        mysteries
        |> Enum.filter(&(&1.category == slug and &1.order in 1..count))
        |> Map.new(&{&1.order, &1})

      card_record =
        if Categories.card_mystery_key(slug),
          do: Map.get(in_category, 1),
          else: seven_sorrows_card

      %{
        slug: slug,
        numeral: Enum.at(@numerals, Categories.position(slug)),
        name: Categories.name(slug),
        title: "The " <> Categories.devotion_title(slug),
        devotion_title: Categories.devotion_title(slug),
        subtitle: Categories.subtitle(slug),
        days: nil,
        path: "/mysteries/#{slug}",
        painting: painting(card_record, slug),
        mysteries: mysteries_in_order(slug, count, in_category)
      }
    end)
  end

  defp mysteries_in_order(slug, count, in_category) do
    Enum.map(1..count, fn order ->
      case Map.get(in_category, order) do
        nil ->
          %{
            key: "#{slug}_#{order}",
            numeral: Enum.at(@numerals, order - 1),
            name: Categories.mystery_label(slug, order),
            fruit: nil,
            record: nil
          }

        mystery ->
          %{
            key: "#{slug}_#{order}",
            numeral: Enum.at(@numerals, order - 1),
            name: mystery.name,
            fruit: mystery.fruit,
            record: mystery
          }
      end
    end)
  end

  # The card keeps the app's framing (MysteryCategory.cardFocalPoint), not
  # the painting's own focal point, which frames it on the mystery's page.
  defp painting(record, slug) do
    if Artwork.publishable?(record) do
      {x, y} = Categories.card_focal_point(slug)

      %{
        record: record,
        alt: record.image_alt,
        position: Artwork.object_position(x, y)
      }
    end
  end

  @doc false
  def schedule_name(:traditional), do: "Traditional"
  def schedule_name(:modern), do: "Modern"

  @doc false
  def schedule_detail(:traditional), do: "Joyful on Thursday, Glorious on Saturday"
  def schedule_detail(:modern), do: "Luminous on Thursday, Joyful on Saturday"

  @doc """
  The line under a set's name in today's list: its kinds, and "Text only"
  for a set with no narration. Narration is the rule, so it is the
  exception that is named.
  """
  def set_detail(set) do
    kinds = Enum.map(set.labels || [], &Labels.display_name/1)
    words = if set.audio_count > 0, do: kinds, else: kinds ++ ["Text only"]

    case words do
      [] -> nil
      words -> Enum.join(words, " · ")
    end
  end

  @doc """
  Where the hero frames today's painting: an uploaded painting's own
  focal point, else the app's framing of the card.
  """
  def hero_position(%{painting: %{position: position}}), do: position

  def hero_position(%{slug: slug}) do
    {x, y} = Categories.card_focal_point(slug)
    Artwork.object_position(x, y)
  end

  @doc "The last card of an odd number takes a phone's whole row."
  def wide_card?(index, categories),
    do: rem(length(categories), 2) == 1 and index == length(categories) - 1

  @doc false
  def scriptural_path(slug), do: "/mysteries/#{slug}/pray?form=scriptural"

  @doc false
  def aloud_path(slug), do: "/mysteries/#{slug}/pray?form=holy"
end
