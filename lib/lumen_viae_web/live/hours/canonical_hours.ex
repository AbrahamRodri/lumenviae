defmodule LumenViaeWeb.Live.Hours.CanonicalHours do
  @moduledoc """
  The eight hours of the Roman Office as the Hours of Prayer pages name and
  order them, the iOS app's `CanonicalHour` (and the Android app's
  `domain/OfficeHours.kt`) line for line: the hour said plainly ("Dawn
  Prayer") over its Church name ("Lauds"), the clock hour its time begins
  at, the painting it hangs and the colour of its time of day.

  Bundled rather than read from `LumenViae.Office.vocabulary/0`, as the
  app bundles them: the landing's ledger renders before anything is
  fetched. The slugs are the Office's own (a test holds the two lists
  together). Fixed clock times, not true solar hours, the boundaries a
  breviary's rubrics assume.

  Also the pages' dates and paths: "today" is the visitor's, from the
  `UserTimezone` hook's offset, the server's until it connects.
  """

  alias LumenViae.Office

  @hours [
    %{
      slug: "matutinum",
      plain: "Night Vigil",
      label: "Matins",
      begins: 0,
      painting: {"sorrowful_agony", 0.5, 0.3}
    },
    %{
      slug: "laudes",
      plain: "Dawn Prayer",
      label: "Lauds",
      begins: 5,
      painting: {"glorious_resurrection", 0.5, 0.2}
    },
    # iOS hangs the Song of the Lark (hour_morning), which the site does not
    # have; its fallback, as on iOS, is the Presentation.
    %{
      slug: "prima",
      plain: "Early Morning Prayer",
      label: "Prime",
      begins: 7,
      painting: {"joyful_presentation", 0.5, 0.3}
    },
    %{
      slug: "tertia",
      plain: "Mid-Morning Prayer",
      label: "Terce",
      begins: 9,
      painting: {"glorious_pentecost", 0.5, 0.3}
    },
    %{
      slug: "sexta",
      plain: "Midday Prayer",
      label: "Sext",
      begins: 12,
      painting: {"sorrowful_crucifixion", 0.5, 0.15}
    },
    %{
      slug: "nona",
      plain: "Mid-Afternoon Prayer",
      label: "Nones",
      begins: 14,
      painting: {"seven_sorrows_descent", 0.5, 0.3}
    },
    %{
      slug: "vesperae",
      plain: "Evening Prayer",
      label: "Vespers",
      begins: 16,
      painting: {"joyful_visitation", 0.5, 0.3}
    },
    %{
      slug: "completorium",
      plain: "Bedtime Prayer",
      label: "Compline",
      begins: 19,
      painting: {"joyful_presentation", 0.5, 0.5}
    }
  ]

  # The hours as a breviary groups them, the landing's three headings.
  @groups [
    {"The Night and the Dawn", ~w(matutinum laudes)},
    {"Through the Day", ~w(prima tertia sexta nona)},
    {"Evening and Night", ~w(vesperae completorium)}
  ]

  @clock_words ~w(twelve one two three four five six seven eight nine ten eleven)

  @doc "The eight hours, Matins first."
  def all, do: @hours

  @doc "The hours' slugs, in order."
  def slugs, do: Enum.map(@hours, & &1.slug)

  @doc "One hour by its slug, or nil."
  def fetch(slug), do: Enum.find(@hours, &(&1.slug == slug))

  @doc "The landing's groups, `{heading, [hour]}`."
  def groups do
    for {heading, slugs} <- @groups, do: {heading, Enum.map(slugs, &fetch/1)}
  end

  @doc "The hour whose traditional time holds `clock_hour` (0 to 23)."
  def present(clock_hour) when clock_hour in 0..23 do
    @hours |> Enum.filter(&(&1.begins <= clock_hour)) |> List.last()
  end

  @doc "The hour before, or nil for Matins: the reader does not roll into yesterday."
  def previous(%{slug: slug}) do
    case Enum.find_index(@hours, &(&1.slug == slug)) do
      0 -> nil
      index -> Enum.at(@hours, index - 1)
    end
  end

  @doc "The hour after, or nil for Compline."
  def next(%{slug: slug}) do
    @hours |> Enum.drop_while(&(&1.slug != slug)) |> Enum.at(1)
  end

  @doc "\"until noon\": when an hour gives way to the next, wrapping at Compline."
  def lapses(%{slug: slug}) do
    index = Enum.find_index(@hours, &(&1.slug == slug))
    following = Enum.at(@hours, rem(index + 1, length(@hours)))
    "until " <> clock_word(following.begins)
  end

  @doc "A clock hour in words, as a breviary would say it."
  def clock_word(0), do: "midnight"
  def clock_word(12), do: "noon"
  def clock_word(hour), do: Enum.at(@clock_words, rem(hour, 12))

  @doc "\"End of Dawn Prayer\", the scribe's close under a finished hour."
  def explicit(%{plain: plain}), do: "End of " <> plain

  @doc "The one line naming where the texts come from, the app's `OfficeCredit`."
  def credit, do: "Texts: Divinum Officium"

  # -- The visitor's clock --------------------------------------------------

  @doc """
  The visitor's local time from the browser's `getTimezoneOffset()` (minutes
  behind UTC), or `:error` for an offset no place keeps.
  """
  def local_now(offset, now \\ DateTime.utc_now())

  def local_now(offset, now) when is_integer(offset) and abs(offset) <= 24 * 60 do
    {:ok, now |> DateTime.add(-offset * 60, :second) |> DateTime.to_naive()}
  end

  def local_now(_offset, _now), do: :error

  @doc "The server's time, until the browser says its own."
  def server_now, do: DateTime.to_naive(DateTime.utc_now())

  # -- Dates and paths ------------------------------------------------------

  @doc """
  A date from the link, `{:ok, date}` only for an ISO 8601 date the Office
  serves; `:error` for anything else.
  """
  def parse_date(value) when is_binary(value) do
    with {:ok, date} <- Date.from_iso8601(value),
         true <- Office.serves?(date) do
      {:ok, date}
    else
      _ -> :error
    end
  end

  def parse_date(_value), do: :error

  @doc "A year and month from the link, `{:ok, {year, month}}` or `:error`."
  def parse_month(year, month) when is_binary(year) and is_binary(month) do
    with {year, ""} <- Integer.parse(year),
         {month, ""} <- Integer.parse(month),
         true <- month in 1..12,
         true <- Office.serves?(Date.new!(year, month, 1)) do
      {:ok, {year, month}}
    else
      _ -> :error
    end
  rescue
    ArgumentError -> :error
  end

  def parse_month(_year, _month), do: :error

  def day_path(%Date{} = date), do: "/hours/" <> Date.to_iso8601(date)

  def hour_path(date, slug, language \\ "english")
  def hour_path(%Date{} = date, slug, "english"), do: day_path(date) <> "/" <> slug
  def hour_path(%Date{} = date, slug, language), do: hour_path(date, slug) <> "?lang=" <> language

  def calendar_path(%Date{year: year, month: month}), do: calendar_path(year, month)
  def calendar_path(year, month), do: "/hours/calendar/#{year}/#{month}"

  @doc "\"Thursday, 27 August 2026\", the app's plate date with its year."
  def long_date(%Date{} = date), do: Calendar.strftime(date, "%A, %-d %B %Y")

  @doc "\"November 2026\"."
  def month_title(year, month), do: Calendar.strftime(Date.new!(year, month, 1), "%B %Y")
end
