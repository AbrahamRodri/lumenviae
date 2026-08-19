defmodule LumenViae.Rosary.AttributionTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Byline Set #{System.unique_integer([:positive])}", category: "sorrowful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  defp add_meditation(set, attrs) do
    {:ok, mystery} =
      Rosary.create_mystery(%{
        name: "Mystery #{System.unique_integer([:positive])}",
        category: "sorrowful",
        order: System.unique_integer([:positive])
      })

    {:ok, meditation} =
      Rosary.create_meditation(
        Map.merge(%{content: "Some content", mystery_id: mystery.id}, attrs)
      )

    order = length(Rosary.list_meditations_in_set(set.id)) + 1
    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order)
    meditation
  end

  describe "resolve_attribution/1" do
    test "derives the byline when every meditation agrees" do
      set = create_set()

      add_meditation(set, %{author: "Bl. Anne Catherine Emmerich", source: "The Dolorous Passion"})

      add_meditation(set, %{author: "Bl. Anne Catherine Emmerich", source: "The Dolorous Passion"})

      resolved = Rosary.resolve_attribution(set)

      assert resolved.derived_author == "Bl. Anne Catherine Emmerich"
      assert resolved.derived_source == "The Dolorous Passion"
    end

    # A name that is true of most of a set is worse than no name at all.
    test "derives nothing when the meditations disagree" do
      set = create_set()
      add_meditation(set, %{author: "Bl. Anne Catherine Emmerich"})
      add_meditation(set, %{author: "St. Alphonsus Liguori"})

      resolved = Rosary.resolve_attribution(set)

      assert resolved.derived_author == nil
    end

    test "derives each field independently" do
      set = create_set()
      add_meditation(set, %{author: "Emmerich", source: "The Dolorous Passion"})
      add_meditation(set, %{author: "Emmerich", source: "The Life of Our Lord"})

      resolved = Rosary.resolve_attribution(set)

      assert resolved.derived_author == "Emmerich"
      assert resolved.derived_source == nil
    end

    test "derives nothing for an empty set" do
      resolved = Rosary.resolve_attribution(create_set())

      assert resolved.derived_author == nil
      assert resolved.derived_source == nil
    end

    test "treats a blank author as absent rather than as a value to agree on" do
      set = create_set()
      add_meditation(set, %{author: "Emmerich"})
      add_meditation(set, %{author: "   "})

      assert Rosary.resolve_attribution(set).derived_author == nil
    end

    # The whole point of the virtual fields: a struct that has been through
    # the derivation must still save without promoting a guess to an override.
    test "never writes the derivation into the persisted columns" do
      set = create_set()
      add_meditation(set, %{author: "Emmerich", source: "The Dolorous Passion"})

      resolved = Rosary.resolve_attribution(set)

      assert resolved.author == nil
      assert resolved.source == nil

      {:ok, saved} = Rosary.update_meditation_set(resolved, %{"name" => "Renamed"})

      assert saved.author == nil
      assert saved.source == nil
    end

    test "resolves a list of sets without querying per set" do
      first = create_set()
      second = create_set()
      add_meditation(first, %{author: "Emmerich"})
      add_meditation(second, %{author: "Liguori"})

      [resolved_first, resolved_second] = Rosary.resolve_attribution([first, second])

      assert resolved_first.derived_author == "Emmerich"
      assert resolved_second.derived_author == "Liguori"
    end
  end

  describe "the byline the API renders" do
    test "an explicit author wins over the derivation" do
      set = create_set(%{author: "Bl. Anne Catherine Emmerich"})
      add_meditation(set, %{author: "A Translator"})

      rendered =
        set.id
        |> Rosary.get_visible_meditation_set_with_ordered_meditations!()
        |> LumenViaeWeb.API.MeditationSetJSON.set_detail()

      assert rendered.author == "Bl. Anne Catherine Emmerich"
    end

    test "the derivation fills the gap when the set says nothing" do
      set = create_set()
      add_meditation(set, %{author: "St. Alphonsus Liguori", source: "The Glories of Mary"})

      rendered =
        set.id
        |> Rosary.get_visible_meditation_set_with_ordered_meditations!()
        |> LumenViaeWeb.API.MeditationSetJSON.set_detail()

      assert rendered.author == "St. Alphonsus Liguori"
      assert rendered.source == "The Glories of Mary"
    end

    test "both are null when there is nothing to say" do
      set = create_set()
      add_meditation(set, %{})

      rendered =
        set.id
        |> Rosary.get_visible_meditation_set_with_ordered_meditations!()
        |> LumenViaeWeb.API.MeditationSetJSON.set_detail()

      assert rendered.author == nil
      assert rendered.source == nil
    end
  end
end
