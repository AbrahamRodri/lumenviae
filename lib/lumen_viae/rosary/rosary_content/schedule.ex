defmodule LumenViae.Rosary.RosaryContent.Schedule do
  @moduledoc """
  The `schedule` section of `LumenViae.Rosary.RosaryContent`: which
  mysteries a day calls for, as rules a client applies offline, computed
  from `LumenViae.LiturgicalCalendar` and shaped as
  `LumenViae.Rosary.Types.RosarySchedule`.

  Both schedules, Sunday by season, the order of the app's home grid, the
  days each set is prayed in the app's words, and every Lent and Advent
  from January 1 of last year through December 31 three years ahead.

  The section is code, not a file in `priv/rosary_content/`, so it is
  dated here: `@rules_updated_at` is when its rules or words last changed,
  and `test/lumen_viae/rosary/rosary_content/schedule_test.exs` pins the
  rules' version against it, as the content files' histories are pinned.
  Change a rule or a word: bump `@rules_updated_at` and add the version
  the test prints. The seasons it serves move on when the UTC year turns,
  which moves the document's version and dates it January 1.
  """
  use Ash.Resource.Calculation

  alias LumenViae.LiturgicalCalendar
  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Types

  @rules_updated_at ~U[2026-10-04 01:00:00Z]

  @weekdays ~w(monday tuesday wednesday thursday friday saturday)

  @impl true
  def calculate(records, _opts, _context) do
    schedule = current_year() |> section() |> shape()

    Enum.map(records, fn _record -> schedule end)
  end

  @doc "The year the section is served for: today's, in UTC."
  @spec current_year() :: integer
  def current_year, do: Date.utc_today().year

  @doc """
  The section as served in `year`, string keys and ISO 8601 dates
  throughout, as a client reads it.
  """
  @spec section(integer) :: map
  def section(year) do
    first = year - 1
    last = year + 3

    rules()
    |> Map.put(
      "seasons",
      for %{season: season, starts_on: starts_on, ends_on: ends_on} <-
            LiturgicalCalendar.seasons(first..last//1) do
        %{
          "season" => Atom.to_string(season),
          "starts_on" => Date.to_iso8601(starts_on),
          "ends_on" => Date.to_iso8601(ends_on)
        }
      end
    )
    |> Map.put("seasons_from", Date.to_iso8601(Date.new!(first, 1, 1)))
    |> Map.put("seasons_through", Date.to_iso8601(Date.new!(last, 12, 31)))
  end

  @doc """
  The section without its seasons: the schedules and their words, which
  change only when the code does.
  """
  @spec rules() :: map
  def rules do
    %{
      "default" => Atom.to_string(LiturgicalCalendar.default_schedule()),
      "schedules" => Enum.map(LiturgicalCalendar.schedules(), &schedule/1)
    }
  end

  @doc "A fingerprint of `rules/0`, pinned in the section's test."
  @spec rules_version() :: String.t()
  def rules_version, do: Content.version(rules())

  @doc "When the rules or their words last changed."
  @spec rules_updated_at() :: DateTime.t()
  def rules_updated_at, do: @rules_updated_at

  @doc """
  When the section served in `year` last changed: the later of the rules'
  date and January 1 of `year`, when its seasons moved on.
  """
  @spec updated_at(integer) :: DateTime.t()
  def updated_at(year) do
    Enum.max([@rules_updated_at, DateTime.new!(Date.new!(year, 1, 1), ~T[00:00:00])], DateTime)
  end

  defp schedule(id) do
    %{
      "id" => Atom.to_string(id),
      "weekdays" =>
        @weekdays
        |> Enum.with_index(1)
        |> Map.new(fn {day, number} ->
          {day, slug(LiturgicalCalendar.weekday_mysteries(number, id))}
        end),
      "sunday" =>
        Map.new([:advent, :lent, :ordinary], fn season ->
          {Atom.to_string(season), slug(LiturgicalCalendar.sunday_mysteries(season))}
        end),
      "grid" => Enum.map(LiturgicalCalendar.week(id) ++ [:seven_sorrows], &slug/1),
      "days" =>
        for category <- LiturgicalCalendar.categories() do
          %{
            "category" => slug(category),
            "days_prayed" => LiturgicalCalendar.days_prayed(category, id),
            "words" => LiturgicalCalendar.days_in_words(category, id)
          }
        end
    }
  end

  # The calendar's atoms are the category slugs, `seven_sorrows` included.
  defp slug(category), do: Atom.to_string(category)

  defp shape(section) do
    %Types.RosarySchedule{
      default: section["default"],
      schedules: Enum.map(section["schedules"], &shape_schedule/1),
      seasons:
        Enum.map(section["seasons"], fn season ->
          %Types.RosarySeason{
            season: season["season"],
            starts_on: Date.from_iso8601!(season["starts_on"]),
            ends_on: Date.from_iso8601!(season["ends_on"])
          }
        end),
      seasons_from: Date.from_iso8601!(section["seasons_from"]),
      seasons_through: Date.from_iso8601!(section["seasons_through"])
    }
  end

  defp shape_schedule(schedule) do
    weekdays = schedule["weekdays"]
    sunday = schedule["sunday"]

    %Types.MysterySchedule{
      id: schedule["id"],
      weekdays: %Types.ScheduleWeekdays{
        monday: weekdays["monday"],
        tuesday: weekdays["tuesday"],
        wednesday: weekdays["wednesday"],
        thursday: weekdays["thursday"],
        friday: weekdays["friday"],
        saturday: weekdays["saturday"]
      },
      sunday: %Types.ScheduleSunday{
        advent: sunday["advent"],
        lent: sunday["lent"],
        ordinary: sunday["ordinary"]
      },
      grid: schedule["grid"],
      days:
        Enum.map(schedule["days"], fn days ->
          %Types.ScheduleDays{
            category: days["category"],
            days_prayed: days["days_prayed"],
            words: days["words"]
          }
        end)
    }
  end
end
