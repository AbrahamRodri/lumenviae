defmodule LumenViae.Meditations.FilteringTest do
  use ExUnit.Case, async: true

  alias LumenViae.Meditations.Filtering
  alias LumenViae.Rosary.{Meditation, MeditationSet, Mystery}

  defp mystery(attrs) do
    struct!(
      Mystery,
      Map.merge(%{id: 1, name: "The Annunciation", category: "joyful", order: 1}, attrs)
    )
  end

  defp meditation(attrs) do
    defaults = %{
      id: 1,
      title: nil,
      author: nil,
      source: nil,
      content: "meditation content",
      audio_url: nil,
      archived_at: nil,
      mystery_id: 1,
      mystery: mystery(%{}),
      meditation_sets: [],
      updated_at: ~N[2026-01-01 00:00:00]
    }

    struct!(Meditation, Map.merge(defaults, attrs))
  end

  defp ids(meditations), do: Enum.map(meditations, & &1.id)

  describe "filter_meditations/2" do
    test "nil and absent filters leave the list untouched" do
      meditations = [meditation(%{id: 1}), meditation(%{id: 2})]

      assert Filtering.filter_meditations(meditations, %{}) == meditations

      assert Filtering.filter_meditations(meditations, %{category: nil, audio: nil}) ==
               meditations
    end

    test "filters by mystery category" do
      joyful = meditation(%{id: 1})
      sorrowful = meditation(%{id: 2, mystery: mystery(%{id: 6, category: "sorrowful"})})

      assert ids(Filtering.filter_meditations([joyful, sorrowful], %{category: "sorrowful"})) ==
               [2]
    end

    test "filters by specific mystery id" do
      first = meditation(%{id: 1, mystery_id: 1})
      second = meditation(%{id: 2, mystery_id: 9})

      assert ids(Filtering.filter_meditations([first, second], %{mystery_id: 9})) == [2]
    end

    test "filters by author" do
      liguori = meditation(%{id: 1, author: "St. Alphonsus Liguori"})
      emmerich = meditation(%{id: 2, author: "Anne Catherine Emmerich"})

      assert ids(
               Filtering.filter_meditations([liguori, emmerich], %{
                 author: "Anne Catherine Emmerich"
               })
             ) == [2]
    end

    test "filters by audio presence, treating empty strings as missing" do
      with_audio = meditation(%{id: 1, audio_url: "a.mp3"})
      empty_audio = meditation(%{id: 2, audio_url: ""})
      no_audio = meditation(%{id: 3})

      list = [with_audio, empty_audio, no_audio]

      assert ids(Filtering.filter_meditations(list, %{audio: "with"})) == [1]
      assert ids(Filtering.filter_meditations(list, %{audio: "without"})) == [2, 3]
    end

    test "filters by archived status" do
      active = meditation(%{id: 1})
      archived = meditation(%{id: 2, archived_at: ~U[2026-01-01 00:00:00Z]})

      list = [active, archived]

      assert ids(Filtering.filter_meditations(list, %{status: "active"})) == [1]
      assert ids(Filtering.filter_meditations(list, %{status: "archived"})) == [2]
      assert ids(Filtering.filter_meditations(list, %{status: nil})) == [1, 2]
    end

    test "filters by set membership" do
      set = struct!(MeditationSet, id: 7, name: "Test Set", category: "joyful", labels: [])
      in_set = meditation(%{id: 1, meditation_sets: [set]})
      orphan = meditation(%{id: 2})

      list = [in_set, orphan]

      assert ids(Filtering.filter_meditations(list, %{set_id: 7})) == [1]
      assert ids(Filtering.filter_meditations(list, %{set_id: :none})) == [2]
      assert ids(Filtering.filter_meditations(list, %{set_id: 99})) == []
    end

    test "query matches title, author, source, mystery name, and content" do
      by_title = meditation(%{id: 1, title: "On Humility"})
      by_author = meditation(%{id: 2, author: "Fulton Sheen"})
      by_source = meditation(%{id: 3, source: "The Glories of Mary"})
      by_mystery = meditation(%{id: 4, mystery: mystery(%{name: "The Visitation"})})
      by_content = meditation(%{id: 5, content: "Consider the charity of Mary"})

      list = [by_title, by_author, by_source, by_mystery, by_content]

      assert ids(Filtering.filter_meditations(list, %{query: "humility"})) == [1]
      assert ids(Filtering.filter_meditations(list, %{query: "sheen"})) == [2]
      assert ids(Filtering.filter_meditations(list, %{query: "glories"})) == [3]
      assert ids(Filtering.filter_meditations(list, %{query: "visitation"})) == [4]
      assert ids(Filtering.filter_meditations(list, %{query: "charity"})) == [5]
    end

    test "combines multiple filters with AND semantics" do
      match = meditation(%{id: 1, author: "Fulton Sheen", audio_url: "a.mp3"})
      wrong_author = meditation(%{id: 2, author: "Other", audio_url: "b.mp3"})
      no_audio = meditation(%{id: 3, author: "Fulton Sheen"})

      assert ids(
               Filtering.filter_meditations([match, wrong_author, no_audio], %{
                 author: "Fulton Sheen",
                 audio: "with"
               })
             ) == [1]
    end
  end

  describe "sort_meditations/2" do
    test "newest and oldest sort by id" do
      list = [meditation(%{id: 2}), meditation(%{id: 3}), meditation(%{id: 1})]

      assert ids(Filtering.sort_meditations(list, "newest")) == [3, 2, 1]
      assert ids(Filtering.sort_meditations(list, "oldest")) == [1, 2, 3]
    end

    test "updated sorts most recently updated first" do
      stale = meditation(%{id: 1, updated_at: ~N[2026-01-01 00:00:00]})
      fresh = meditation(%{id: 2, updated_at: ~N[2026-06-01 00:00:00]})

      assert ids(Filtering.sort_meditations([stale, fresh], "updated")) == [2, 1]
    end

    test "author sorts alphabetically with missing authors last" do
      anon = meditation(%{id: 1})
      sheen = meditation(%{id: 2, author: "Fulton Sheen"})
      emmerich = meditation(%{id: 3, author: "Anne Catherine Emmerich"})

      assert ids(Filtering.sort_meditations([anon, sheen, emmerich], "author")) == [3, 2, 1]
    end

    test "mystery sort orders by category then mystery order" do
      glorious =
        meditation(%{id: 1, mystery: mystery(%{id: 11, category: "glorious", order: 1})})

      joyful_second = meditation(%{id: 2, mystery: mystery(%{id: 2, order: 2})})
      joyful_first = meditation(%{id: 3, mystery: mystery(%{id: 1, order: 1})})

      assert ids(Filtering.sort_meditations([glorious, joyful_second, joyful_first], "mystery")) ==
               [3, 2, 1]
    end

    test "unknown sort falls back to mystery order" do
      sorrowful =
        meditation(%{id: 1, mystery: mystery(%{id: 6, category: "sorrowful", order: 1})})

      joyful = meditation(%{id: 2, mystery: mystery(%{id: 1, order: 1})})

      assert ids(Filtering.sort_meditations([sorrowful, joyful], "bogus")) == [2, 1]
    end
  end
end
