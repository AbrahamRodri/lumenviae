defmodule LumenViae.Rosary.RosaryContent.ScheduleTest do
  @moduledoc """
  The `schedule` section of the content document, and how it dates and
  versions the document. The section is code, so its rules are pinned
  here as the content files' are in `content_test.exs`.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.RosaryContent.Current
  alias LumenViae.Rosary.RosaryContent.Schedule

  # Each {rules_updated_at, rules_version} the section's rules have had,
  # oldest first. Change a rule or a word in LiturgicalCalendar's days:
  # bump @rules_updated_at in Schedule and add the entry the test prints.
  @history [{~U[2026-10-04 01:00:00Z], "18d8f6f7d06e43a7"}]

  test "the rules are dated and versioned as their history last records them" do
    {pinned_at, pinned_version} = List.last(@history)
    updated_at = Schedule.rules_updated_at()
    version = Schedule.rules_version()

    assert {updated_at, version} == {pinned_at, pinned_version}, """
    The schedule's rules changed (now #{DateTime.to_iso8601(updated_at)}, #{version}).
    Bump @rules_updated_at in LumenViae.Rosary.RosaryContent.Schedule and add
      {~U[#{Calendar.strftime(updated_at, "%Y-%m-%d %H:%M:%SZ")}], "#{version}"}
    to @history here.
    """
  end

  test "the history's dates increase and its version changes with each" do
    for [{at_a, version_a}, {at_b, version_b}] <- Enum.chunk_every(@history, 2, 1, :discard) do
      assert DateTime.compare(at_a, at_b) == :lt
      refute version_a == version_b
    end
  end

  describe "section/1" do
    test "covers January 1 of last year through December 31 three years ahead" do
      section = Schedule.section(2026)

      assert section["seasons_from"] == "2025-01-01"
      assert section["seasons_through"] == "2029-12-31"

      assert Enum.map(section["seasons"], &{&1["season"], &1["starts_on"], &1["ends_on"]}) |> hd() ==
               {"lent", "2025-03-05", "2025-04-19"}

      assert List.last(section["seasons"]) ==
               %{"season" => "advent", "starts_on" => "2029-12-02", "ends_on" => "2029-12-24"}
    end

    test "is the rules and the seasons" do
      section = Schedule.section(2026)

      assert Map.drop(section, ~w(seasons seasons_from seasons_through)) == Schedule.rules()
    end
  end

  describe "the document's stamp" do
    test "folds the section into the version, so it moves when the year turns" do
      refute Current.stamp(2026).version == Content.version()
      refute Current.stamp(2026).version == Current.stamp(2027).version
      assert Current.stamp(2026).version == Current.stamp(2026).version
    end

    test "dates the document January 1 once the year's seasons have moved on" do
      assert Schedule.updated_at(2026) == Schedule.rules_updated_at()
      assert Schedule.updated_at(2027) == ~U[2027-01-01 00:00:00Z]

      assert Current.stamp(2027).updated_at ==
               Enum.max([Content.updated_at(), ~U[2027-01-01 00:00:00Z]], DateTime)
    end
  end
end
