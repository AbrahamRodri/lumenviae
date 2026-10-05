defmodule LumenViae.Rosary.CompletionTalliesTest do
  @moduledoc """
  The dashboard's completion figures, counted by Postgres in grouped and
  aggregate queries, are the figures the old in-memory folds produced:
  each test checks the new answer against the old fold of the same rows,
  and the day buckets across both of 2026's DST changes.
  """
  use LumenViae.DataCase, async: true

  require Ash.Query

  alias LumenViae.CentralTime
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completion

  defp create_set do
    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Tally #{System.unique_integer([:positive])}", category: "joyful"},
        actor: admin()
      )

    set
  end

  defp seed(set, completed_at, attrs \\ %{}) do
    Ash.Seed.seed!(
      Completion,
      Map.merge(
        %{meditation_set_id: set.id, completed_at: DateTime.truncate(completed_at, :second)},
        attrs
      )
    )
  end

  defp ago(days, hours \\ 0) do
    DateTime.add(DateTime.utc_now(), -(days * 24 + hours) * 3600, :second)
  end

  # The fold completion_locations/2 used before the grouped queries.
  defp old_locations(rows) do
    ranked = fn rows, key ->
      rows
      |> Enum.frequencies_by(key)
      |> Enum.sort_by(fn {group, count} -> {-count, elem(group, 0)} end)
    end

    %{
      countries:
        rows
        |> Enum.reject(&is_nil(&1.country))
        |> ranked.(&{&1.country, &1.country_code})
        |> Enum.map(fn {{country, code}, count} ->
          %{country: country, country_code: code, count: count}
        end),
      cities:
        rows
        |> Enum.reject(&is_nil(&1.city))
        |> ranked.(&{&1.city, &1.region, &1.country_code})
        |> Enum.map(fn {{city, region, code}, count} ->
          %{city: city, region: region, country_code: code, count: count}
        end),
      sources: Enum.frequencies_by(rows, & &1.source),
      prayed_aloud: Enum.frequencies_by(rows, & &1.prayed_aloud),
      located: Enum.count(rows, &(not is_nil(&1.country_code))),
      total: length(rows)
    }
  end

  describe "completion_locations/2" do
    test "matches the old fold, ties, blanks and all" do
      set = create_set()

      places = [
        %{city: "Paris", region: "Texas", country: "United States", country_code: "US"},
        %{city: "Paris", region: "Ile-de-France", country: "France", country_code: "FR"},
        %{city: "Paris", region: "Ile-de-France", country: "France", country_code: "FR"},
        %{city: "Austin", region: "Texas", country: "United States", country_code: "US"},
        %{city: nil, region: nil, country: "Mexico", country_code: "MX"},
        %{city: nil, region: nil, country: nil, country_code: nil},
        %{city: "Zurich", region: "Zurich", country: "Switzerland", country_code: "CH"},
        %{city: "amsterdam", region: "North Holland", country: "Netherlands", country_code: "NL"}
      ]

      rows =
        for {place, i} <- Enum.with_index(places) do
          attrs =
            Map.merge(place, %{
              source: Enum.at(["web", "ios", "android", nil], rem(i, 4)),
              prayed_aloud: Enum.at([true, false, nil], rem(i, 3))
            })

          seed(set, ago(1, i), attrs)
          attrs
        end

      # Outside the window: not counted.
      seed(set, ago(40), %{country: "Peru", country_code: "PE", source: "web"})

      assert Rosary.completion_locations(30, actor: admin()) == old_locations(rows)
    end

    test "an empty window" do
      assert Rosary.completion_locations(30, actor: admin()) == %{
               countries: [],
               cities: [],
               sources: %{},
               prayed_aloud: %{},
               located: 0,
               total: 0
             }
    end

    test "is the admin's alone" do
      assert_raise Ash.Error.Forbidden, fn -> Rosary.completion_locations(30) end
    end
  end

  describe "completion_summary/1" do
    test "each window and the one before it, and distinct sets" do
      one = create_set()
      two = create_set()

      seed(one, DateTime.utc_now())
      seed(one, ago(3))
      seed(two, ago(5))
      seed(two, ago(10))
      seed(one, ago(20))
      seed(two, ago(45))
      seed(one, ago(90))

      assert Rosary.completion_summary(actor: admin()) == %{
               total: 7,
               today: 1,
               last_7: 3,
               previous_7: 1,
               last_30: 5,
               previous_30: 1,
               active_sets_30: 2
             }
    end
  end

  describe "completions_by_day/2" do
    test "counts each day of the window, oldest first, zeros filled in" do
      set = create_set()
      today = CentralTime.today()
      noon = fn date -> DateTime.add(CentralTime.day_start(date), 12 * 3600, :second) end

      seed(set, noon.(Date.add(today, -2)))
      seed(set, noon.(Date.add(today, -2)))
      seed(set, noon.(Date.add(today, -5)))
      # Before the window.
      seed(set, noon.(Date.add(today, -9)))

      series = Rosary.completions_by_day(7, actor: admin())

      assert Enum.map(series, & &1.date) == Enum.map(-6..0, &Date.add(today, &1))

      assert Enum.map(series, & &1.count) == [0, 1, 0, 0, 2, 0, 0]
    end
  end

  describe "the :daily_counts action" do
    defp daily(since, until) do
      Completion
      |> Ash.ActionInput.for_action(:daily_counts, %{
        since: since,
        until: until,
        time_zone: "America/Chicago"
      })
      |> Ash.run_action!(actor: admin())
    end

    defp local_days(set) do
      Completion
      |> Ash.Query.filter(meditation_set_id == ^set.id)
      |> Ash.Query.load(local_day: %{time_zone: "America/Chicago"})
      |> Ash.read!(actor: admin())
      |> Enum.frequencies_by(& &1.local_day)
      |> Enum.sort_by(&elem(&1, 0), Date)
      |> Enum.map(fn {date, count} -> %{date: date, count: count} end)
    end

    test "buckets by Central day across the spring change, as local_day does" do
      set = create_set()

      # CST until 2am on 8 March 2026, CDT after.
      for at <- [
            ~U[2026-03-08 05:30:00Z],
            ~U[2026-03-08 07:30:00Z],
            ~U[2026-03-09 04:30:00Z],
            ~U[2026-03-09 05:30:00Z]
          ],
          do: seed(set, at)

      expected = [
        %{date: ~D[2026-03-07], count: 1},
        %{date: ~D[2026-03-08], count: 2},
        %{date: ~D[2026-03-09], count: 1}
      ]

      assert daily(~U[2026-03-01 00:00:00Z], ~U[2026-03-31 00:00:00Z]) == expected
      assert local_days(set) == expected
    end

    test "buckets by Central day across the autumn change, as local_day does" do
      set = create_set()

      # CDT until 2am on 1 November 2026, CST after.
      for at <- [
            ~U[2026-11-01 04:30:00Z],
            ~U[2026-11-01 05:30:00Z],
            ~U[2026-11-02 05:30:00Z],
            ~U[2026-11-02 06:30:00Z]
          ],
          do: seed(set, at)

      expected = [
        %{date: ~D[2026-10-31], count: 1},
        %{date: ~D[2026-11-01], count: 2},
        %{date: ~D[2026-11-02], count: 1}
      ]

      assert daily(~U[2026-10-25 00:00:00Z], ~U[2026-11-10 00:00:00Z]) == expected
      assert local_days(set) == expected
    end
  end

  describe "get_completions_by_set/1" do
    test "ranks in the query: no zeros, most first, ties by id, limited" do
      [a, b, c, _never] = for _ <- 1..4, do: create_set()

      for _ <- 1..3, do: seed(b, ago(1))
      for _ <- 1..2, do: seed(a, ago(2))
      for _ <- 1..2, do: seed(c, ago(3))
      # Outside the window: ranks c above a over all time, not in it.
      for _ <- 1..3, do: seed(c, ago(60))

      windowed = Rosary.get_completions_by_set(days: 30, actor: admin())

      assert Enum.map(windowed, &{&1.set_id, &1.count}) ==
               [{b.id, 3}] ++ Enum.sort([{a.id, 2}, {c.id, 2}])

      assert [%{set_id: id}] = Rosary.get_completions_by_set(days: 30, limit: 1, actor: admin())
      assert id == b.id

      assert [%{set_id: first, count: 5} | _] = Rosary.get_completions_by_set(actor: admin())
      assert first == c.id
    end
  end
end
