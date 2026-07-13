defmodule LumenViae.Meditations.SetFilteringTest do
  use ExUnit.Case, async: true

  alias LumenViae.Meditations.SetFiltering
  alias LumenViae.Rosary.MeditationSet

  defp set(attrs) do
    defaults = %{id: 1, name: "A Set", category: "joyful", description: nil, labels: []}
    struct!(MeditationSet, Map.merge(defaults, attrs))
  end

  defp ids(sets), do: Enum.map(sets, & &1.id)

  defp stats(counts) do
    Map.new(counts, fn {id, count} ->
      {id, %{meditation_count: count, audio_count: 0, archived_count: 0}}
    end)
  end

  describe "expected_meditation_count/1" do
    test "seven sorrows sets hold seven meditations, others five" do
      assert SetFiltering.expected_meditation_count("seven_sorrows") == 7
      assert SetFiltering.expected_meditation_count("joyful") == 5
      assert SetFiltering.expected_meditation_count("glorious") == 5
    end
  end

  describe "filter_sets/3" do
    test "empty filters return every set" do
      sets = [set(%{id: 1}), set(%{id: 2})]

      assert SetFiltering.filter_sets(sets, %{}) == sets
    end

    test "filters by category" do
      joyful = set(%{id: 1})
      sorrows = set(%{id: 2, category: "seven_sorrows"})

      assert ids(SetFiltering.filter_sets([joyful, sorrows], %{category: "seven_sorrows"})) == [2]
    end

    test "filters by label" do
      saints = set(%{id: 1, labels: ["Saints", "Contemplative"]})
      plain = set(%{id: 2})

      assert ids(SetFiltering.filter_sets([saints, plain], %{label: "Saints"})) == [1]
      assert ids(SetFiltering.filter_sets([saints, plain], %{label: "Intentions"})) == []
    end

    test "filters by visibility using the hidden id set" do
      visible = set(%{id: 1})
      hidden = set(%{id: 2})
      context = %{hidden_ids: MapSet.new([2])}

      assert ids(SetFiltering.filter_sets([visible, hidden], %{visibility: "visible"}, context)) ==
               [1]

      assert ids(SetFiltering.filter_sets([visible, hidden], %{visibility: "hidden"}, context)) ==
               [2]
    end

    test "filters by completeness using the stats map" do
      complete = set(%{id: 1})
      partial = set(%{id: 2})
      empty = set(%{id: 3})
      full_sorrows = set(%{id: 4, category: "seven_sorrows"})
      context = %{stats: stats(%{1 => 5, 2 => 3, 4 => 7})}

      sets = [complete, partial, empty, full_sorrows]

      assert ids(SetFiltering.filter_sets(sets, %{completeness: "complete"}, context)) == [1, 4]
      assert ids(SetFiltering.filter_sets(sets, %{completeness: "incomplete"}, context)) == [2, 3]
      assert ids(SetFiltering.filter_sets(sets, %{completeness: "empty"}, context)) == [3]
    end

    test "query matches name, description, and labels" do
      by_name = set(%{id: 1, name: "Seven Sorrows with Emmerich"})
      by_description = set(%{id: 2, description: "Meditations for the sick"})
      by_label = set(%{id: 3, labels: ["Scriptural"]})
      no_match = set(%{id: 4})

      sets = [by_name, by_description, by_label, no_match]

      assert ids(SetFiltering.filter_sets(sets, %{query: "emmerich"})) == [1]
      assert ids(SetFiltering.filter_sets(sets, %{query: "sick"})) == [2]
      assert ids(SetFiltering.filter_sets(sets, %{query: "scriptural"})) == [3]
    end
  end

  describe "sort_sets/3" do
    test "sorts by name, newest, and meditation count" do
      first = set(%{id: 1, name: "Zeal"})
      second = set(%{id: 2, name: "Adoration"})
      sets = [first, second]

      assert ids(SetFiltering.sort_sets(sets, "name")) == [2, 1]
      assert ids(SetFiltering.sort_sets(sets, "newest")) == [2, 1]

      counts = stats(%{1 => 5, 2 => 2})
      assert ids(SetFiltering.sort_sets(sets, "meditations", counts)) == [1, 2]
    end

    test "default sort is category order" do
      glorious = set(%{id: 1, category: "glorious"})
      joyful = set(%{id: 2})

      assert ids(SetFiltering.sort_sets([glorious, joyful], "category")) == [2, 1]
      assert ids(SetFiltering.sort_sets([glorious, joyful], "bogus")) == [2, 1]
    end
  end
end
