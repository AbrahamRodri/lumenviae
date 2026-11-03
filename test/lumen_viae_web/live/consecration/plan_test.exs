defmodule LumenViaeWeb.Live.Consecration.PlanTest do
  @moduledoc """
  The Consecration's date arithmetic, as the app's (`MarianFeastDay`,
  `FeastPreparation`, `ConsecrationProgress`): Day 1 thirty-three days
  before each feast, only preparations that can still begin on Day 1,
  today's day of a plan, and the browser's state read safely.
  """
  use ExUnit.Case, async: true

  alias LumenViaeWeb.Live.Consecration.{Days, Plan}

  setup_all do
    %{doc: Days.load(nil)}
  end

  describe "each feast's Day 1" do
    # The app's own table: feast, then Day 1, in 2026.
    @starts %{
      "lourdes" => {~D[2026-02-11], ~D[2026-01-09]},
      "annunciation" => {~D[2026-03-25], ~D[2026-02-20]},
      "mount_carmel" => {~D[2026-07-16], ~D[2026-06-13]},
      "assumption" => {~D[2026-08-15], ~D[2026-07-13]},
      "nativity_mary" => {~D[2026-09-08], ~D[2026-08-06]},
      "sorrows" => {~D[2026-09-15], ~D[2026-08-13]},
      "presentation_mary" => {~D[2026-11-21], ~D[2026-10-19]},
      "immaculate_conception" => {~D[2026-12-08], ~D[2026-11-05]},
      "guadalupe" => {~D[2026-12-12], ~D[2026-11-09]}
    }

    test "is 33 days before the feast, for every feast", %{doc: doc} do
      assert length(doc.feasts) == map_size(@starts)

      for feast <- doc.feasts do
        {feast_date, start} = @starts[feast.id]
        prep = Plan.preparation(feast, ~D[2026-01-01])

        assert prep.feast_date == feast_date, feast.id
        assert prep.start == start, feast.id
        assert Plan.consecration_date(prep.start) == feast_date, feast.id
        assert Plan.feast_ending(doc.feasts, start).id == feast.id
      end
    end

    test "a preparation already under way is next year's", %{doc: doc} do
      assumption = Enum.find(doc.feasts, &(&1.id == "assumption"))

      assert Plan.preparation(assumption, ~D[2026-07-13]).start == ~D[2026-07-13]
      assert Plan.preparation(assumption, ~D[2026-07-14]).start == ~D[2027-07-13]
    end

    test "the preparations are the soonest Day 1 first", %{doc: doc} do
      [first, second | _] = Plan.preparations(doc.feasts, ~D[2026-11-02])

      assert first.feast.id == "immaculate_conception"
      assert first.start == ~D[2026-11-05]
      assert second.feast.id == "guadalupe"
      assert length(Plan.preparations(doc.feasts, ~D[2026-11-02])) == 9
    end
  end

  describe "where a plan stands" do
    test "before Day 1, on a day, held at 34, and completed" do
      plan = %{start: ~D[2026-11-05], feast_id: nil, completed_at: nil}

      assert Plan.status(nil, ~D[2026-11-02]) == :none
      assert Plan.status(plan, ~D[2026-11-02]) == {:scheduled, ~D[2026-11-05]}
      assert Plan.status(plan, ~D[2026-11-05]) == {:day, 1}
      assert Plan.status(plan, ~D[2026-11-19]) == {:day, 15}
      assert Plan.status(plan, ~D[2026-12-08]) == {:day, 34}
      assert Plan.status(plan, ~D[2027-03-01]) == {:day, 34}

      assert Plan.status(%{plan | completed_at: "2026-12-08T10:00:00Z"}, ~D[2026-12-08]) ==
               :completed
    end

    test "Start at any day counts back from today" do
      assert Plan.start_at(1, ~D[2026-11-02]) == ~D[2026-11-02]
      assert Plan.start_at(15, ~D[2026-11-02]) == ~D[2026-10-19]
      assert Plan.consecration_date(Plan.start_at(15, ~D[2026-11-02])) == ~D[2026-11-21]
      assert Plan.any_day("40") == 33
      assert Plan.any_day("0") == 1
      assert Plan.any_day("x") == 1
      assert Plan.any_day(["1"]) == 1
    end
  end

  describe "what the browser hands the page" do
    test "keeps a plan with a date, drops anything else", %{doc: doc} do
      assert %{start: ~D[2026-11-05], feast_id: "immaculate_conception"} =
               Plan.parse(
                 %{"start" => "2026-11-05", "feast_id" => "immaculate_conception"},
                 doc.feasts
               )

      assert %{feast_id: nil} =
               Plan.parse(%{"start" => "2026-11-05", "feast_id" => "nope"}, doc.feasts)

      assert Plan.parse(%{"start" => "soon"}, doc.feasts) == nil
      assert Plan.parse(%{"start" => 5}, doc.feasts) == nil
      assert Plan.parse("x", doc.feasts) == nil
      assert Plan.parse(nil, doc.feasts) == nil
    end

    test "keeps days prayed from 1 to 34, once each, in order" do
      assert Plan.parse_done([3, 1, 3, 0, 35, "2", 34]) == [1, 3, 34]
      assert Plan.parse_done("1,2") == []
      assert Plan.parse_date("2026-11-02", ~D[2000-01-01]) == ~D[2026-11-02]
      assert Plan.parse_date("nope", ~D[2000-01-01]) == ~D[2000-01-01]
      assert Plan.parse_date(%{}, ~D[2000-01-01]) == ~D[2000-01-01]
    end
  end

  describe "words for dates" do
    test "as the app says them" do
      today = ~D[2026-11-02]

      assert Plan.long_date(~D[2026-11-21], today) == "Saturday, November 21"
      assert Plan.long_date(~D[2027-02-11], today) == "Thursday, February 11, 2027"
      assert Plan.long_date(~D[2026-11-21], today, false) == "November 21"
      assert Plan.short_date(~D[2026-12-12], today) == "Dec 12"
      assert Plan.countdown(0) == "today"
      assert Plan.countdown(1) == "tomorrow"
      assert Plan.countdown(12) == "in 12 days"
    end
  end
end
