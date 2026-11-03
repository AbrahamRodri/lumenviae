defmodule LumenViaeWeb.Live.Home.TodaysPrayer do
  @moduledoc """
  "Today's Prayer" on the home page, the iOS app's `TodaysPrayerSection`
  (and the Android app's `domain/TodaysPrayer.kt`): the day's rows, each a
  painting, its name, one line saying what today holds and its own live
  fact in small capitals. The Consecration to Mary, the hour's order of
  prayer, then the Hours of Prayer.

  The app's third row, Today's Mass, is left out: the website has no
  Daily Missal yet, and it makes no call to Missale Meum.

  Everything here is the visitor's: the Consecration from the plan the
  `ConsecrationPlan` hook reads from this browser
  (`LumenViaeWeb.Live.Consecration.Plan` does its date arithmetic), the
  hours from the browser's clock (the `UserTimezone` hook's offset). The
  website keeps nothing about a visitor, so the hour's order is never
  marked prayed, as the Prayers page's Now card never is; the
  Consecration's day is, from the days the browser kept.

  Presentation only: `load/1` reads the Consecration and the Prayer Book
  through their page modules (and so through `LumenViae.Rosary`), and
  keeps only what the rows need.
  """

  alias LumenViaeWeb.Live.Consecration.{Days, Plan}
  alias LumenViaeWeb.Live.Hours.CanonicalHours
  alias LumenViaeWeb.Live.Prayers.{Book, Orders}

  @name "Consecration to Mary"
  @invitation "Give yourself to Jesus through Mary"
  @coronation_focal 0.12
  @under_way_focal 0.25

  # PrayerBookPainting.topic(id: "day"), the Hours of Prayer row's.
  @office_painting {"topic_daily_prayers", 0.5, 0.45}

  @doc """
  What the rows need, read once on mount: each day's title, the phases'
  spans and paintings, and the day's three orders of prayer.
  """
  def load(actor) do
    doc = Days.load(actor)
    book = Book.load(actor)

    %{
      day_titles: Map.new(doc.days, &{&1.number, &1.title}),
      phases: Enum.map(doc.phases, &Map.take(&1, [:first_day, :last_day, :painting])),
      orders: Map.new(Orders.day_orders(book), &{&1.id, &1})
    }
  end

  # ---- The header

  @doc "\"MON 2 NOV\", beside the heading (the app's \"EEE d MMM\", in capitals)."
  def date_line(%Date{} = date), do: date |> Calendar.strftime("%a %-d %b") |> String.upcase()

  # ---- The Consecration to Mary

  @doc """
  The Consecration's row on `today`, from the plan the browser keeps and
  the days it has prayed. `completed_on` is the visitor's date the Act was
  made, if it was: made today, the row keeps its place and its seal for
  the day; made earlier, the row invites a new one.

  A row is `%{id:, path:, painting:, name:, subtitle:, fact:, mark:,
  prayed?:, spoken:}`.
  """
  def consecration(data, plan, done, today, completed_on) do
    coronation = painting_for(data, Plan.last_day(), @coronation_focal)
    consecration_title = Map.get(data.day_titles, Plan.last_day(), "Total Consecration")

    case Plan.status(plan, today) do
      :completed when completed_on == today ->
        row(:consecration, Days.path(), coronation, @name, consecration_title,
          fact: "Consecrated today",
          prayed?: true,
          spoken: "#{@name}, #{consecration_title}, consecrated today"
        )

      {:scheduled, start} ->
        row(:consecration, Days.path(), coronation, @name, @invitation,
          fact: "Begins " <> Calendar.strftime(start, "%b %-d"),
          spoken: "#{@name}. #{@invitation}. Begins #{Calendar.strftime(start, "%A, %B %-d")}"
        )

      {:day, day} ->
        under_way(data, plan, done, today, day)

      _none_or_made_earlier ->
        row(:consecration, Days.path(), coronation, @name, @invitation,
          fact: "Begin",
          spoken: "#{@name}. #{@invitation}, a 33-day preparation. Begin."
        )
    end
  end

  # Day 1 to 33, then the day of consecration, which "DAY 34 OF 33" would
  # be no way to say. Past it, with the Act not yet made, the row says it
  # is ready, never that it is late.
  defp under_way(data, plan, done, today, day) do
    days_in = Date.diff(today, plan.start) + 1
    title = Map.get(data.day_titles, day, "")
    prayed? = day in done

    {fact, spoken_day} =
      cond do
        days_in < Plan.last_day() -> {"Day #{day} of 33", "day #{day} of 33"}
        days_in == Plan.last_day() -> {"The day of consecration", "the day of consecration"}
        true -> {"Ready to consecrate", "ready to consecrate"}
      end

    focal = if day >= Plan.last_day(), do: @coronation_focal, else: @under_way_focal

    spoken =
      [@name, title, spoken_day, if(prayed?, do: "prayed today")]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(", ")

    row(:consecration, Days.day_path(day), painting_for(data, day, focal), @name, title,
      fact: fact,
      prayed?: prayed?,
      spoken: spoken
    )
  end

  defp painting_for(data, day, focal) do
    phase = Enum.find(data.phases, &(day >= &1.first_day and day <= &1.last_day))
    {(phase && phase.painting) || "glorious_coronation", 0.5, focal}
  end

  # ---- The hour's prayers

  @doc """
  The Prayer Book's order for the hour it is at `now` (Morning Prayers,
  the Angelus, Night Prayers), said in the Prayers page's own sentence,
  with when it is said as its fact. Nil if the book lacks the order.
  """
  def hour_order(data, %NaiveDateTime{} = now) do
    date = NaiveDateTime.to_date(now)

    case Map.get(data.orders, Orders.day_order_id(now.hour)) do
      nil ->
        nil

      order ->
        title = Orders.title(order, date)
        summary = Orders.day_summary(order, date)
        moment = moment(now.hour)

        row(
          :hour_order,
          Orders.order_path(order.id),
          Orders.hour_painting(order, date) || {"glorious_coronation", 0.5, 0.12},
          title,
          summary,
          fact: moment,
          spoken:
            Enum.join([title, String.trim_trailing(summary, "."), String.downcase(moment)], ", ")
        )
    end
  end

  @doc """
  When the hour's order is said (PrayerBook.dayOrderMoment): "On waking",
  "At noon", "At 6 PM", "At bedtime".
  """
  def moment(hour) when hour >= 4 and hour < 11, do: "On waking"
  def moment(hour) when hour >= 11 and hour < 15, do: "At noon"
  def moment(hour) when hour >= 15 and hour < 20, do: "At 6 PM"
  def moment(_hour), do: "At bedtime"

  # ---- The Hours of Prayer

  @doc "The hour of the Office it is at `now`, and how long it is the hour: NOW · UNTIL NOON."
  def office(%NaiveDateTime{hour: hour}) do
    present = CanonicalHours.present(hour)
    lapses = CanonicalHours.lapses(present)

    row(
      :office,
      "/hours",
      @office_painting,
      "Hours of Prayer",
      "#{present.plain} (#{present.label})",
      fact: "Now · " <> lapses,
      mark: :lit_hour,
      spoken: "Hours of Prayer, #{present.plain}, #{present.label}, the hour now, #{lapses}"
    )
  end

  # ---- The clock

  @doc """
  How long from `now` until the next hour begins, in milliseconds: every
  turn of the rows (the book's four, eleven, three and eight o'clock, the
  Office's hours, the date) falls on the hour.
  """
  def next_turn_in(%NaiveDateTime{} = now) do
    next =
      now
      |> NaiveDateTime.truncate(:second)
      |> Map.merge(%{minute: 0, second: 0})
      |> NaiveDateTime.add(3600, :second)

    NaiveDateTime.diff(next, now, :millisecond)
  end

  defp row(id, path, painting, name, subtitle, opts) do
    %{
      id: id,
      path: path,
      painting: painting,
      name: name,
      subtitle: subtitle,
      fact: Keyword.fetch!(opts, :fact),
      mark: Keyword.get(opts, :mark),
      prayed?: Keyword.get(opts, :prayed?, false),
      spoken: Keyword.fetch!(opts, :spoken)
    }
  end
end
