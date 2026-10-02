defmodule LumenViae.Rosary.AttributionTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Byline Set #{System.unique_integer([:positive])}", category: "sorrowful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs), actor: admin())
    set
  end

  defp add_meditation(set, attrs) do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Mystery #{System.unique_integer([:positive])}",
          category: "sorrowful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(
        Map.merge(%{content: "Some content", mystery_id: mystery.id}, attrs),
        actor: admin()
      )

    order = length(Rosary.list_meditations_in_set(set.id, actor: admin())) + 1
    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order, actor: admin())
    meditation
  end

  # The set as the admin's list reads it, derivation included.
  defp listed(set) do
    Enum.find(Rosary.list_meditation_sets!(actor: admin()), &(&1.id == set.id))
  end

  describe "the derived byline" do
    test "derives the byline when every meditation agrees" do
      set = create_set()

      add_meditation(set, %{author: "Bl. Anne Catherine Emmerich", source: "The Dolorous Passion"})

      add_meditation(set, %{author: "Bl. Anne Catherine Emmerich", source: "The Dolorous Passion"})

      resolved = listed(set)

      assert resolved.derived_author == "Bl. Anne Catherine Emmerich"
      assert resolved.derived_source == "The Dolorous Passion"
    end

    # A name that is true of most of a set is worse than no name at all.
    test "derives nothing when the meditations disagree" do
      set = create_set()
      add_meditation(set, %{author: "Bl. Anne Catherine Emmerich"})
      add_meditation(set, %{author: "St. Alphonsus Liguori"})

      resolved = listed(set)

      assert resolved.derived_author == nil
    end

    test "derives each field independently" do
      set = create_set()
      add_meditation(set, %{author: "Emmerich", source: "The Dolorous Passion"})
      add_meditation(set, %{author: "Emmerich", source: "The Life of Our Lord"})

      resolved = listed(set)

      assert resolved.derived_author == "Emmerich"
      assert resolved.derived_source == nil
    end

    test "derives nothing for an empty set" do
      resolved = listed(create_set())

      assert resolved.derived_author == nil
      assert resolved.derived_source == nil
    end

    test "treats a blank author as absent rather than as a value to agree on" do
      set = create_set()
      add_meditation(set, %{author: "Emmerich"})
      add_meditation(set, %{author: "   "})

      assert listed(set).derived_author == nil
    end

    test "trims a meditation's attribution before comparing it" do
      set = create_set()
      add_meditation(set, %{author: "Emmerich"})
      add_meditation(set, %{author: "  Emmerich "})

      assert listed(set).derived_author == "Emmerich"
    end

    test "a meditation naming nobody is a disagreement, not an abstention" do
      set = create_set()
      add_meditation(set, %{author: "Emmerich"})
      add_meditation(set, %{})

      assert listed(set).derived_author == nil
    end

    # The whole point of deriving rather than storing: a record that carries
    # the derivation must still save without promoting a guess to an
    # override.
    test "never writes the derivation into the persisted columns" do
      set = create_set()
      add_meditation(set, %{author: "Emmerich", source: "The Dolorous Passion"})

      resolved = listed(set)

      assert resolved.author == nil
      assert resolved.source == nil

      {:ok, saved} =
        Rosary.update_meditation_set(resolved, %{"name" => "Renamed"}, actor: admin())

      assert saved.author == nil
      assert saved.source == nil
    end

    test "each set in a list gets its own" do
      first = create_set()
      second = create_set()
      add_meditation(first, %{author: "Emmerich"})
      add_meditation(second, %{author: "Liguori"})

      assert listed(first).derived_author == "Emmerich"
      assert listed(second).derived_author == "Liguori"
    end

    test "every public read carries it" do
      set = create_set()
      add_meditation(set, %{author: "Emmerich", source: "The Dolorous Passion"})

      {:ok, fetched} = Rosary.fetch_visible_meditation_set(set.id)

      reads = [
        fetched,
        Rosary.get_visible_meditation_set_with_ordered_meditations!(set.id),
        Enum.find(Rosary.list_visible_meditation_sets!(), &(&1.id == set.id)),
        Enum.find(Rosary.list_visible_meditation_sets_with_meditations!(), &(&1.id == set.id)),
        Enum.find(
          Rosary.list_visible_meditation_sets_by_category!("sorrowful"),
          &(&1.id == set.id)
        )
      ]

      for read <- reads do
        assert read.derived_author == "Emmerich"
        assert read.derived_source == "The Dolorous Passion"
      end
    end
  end

  describe "byline_author and byline_source" do
    defp byline(set) do
      set = Ash.load!(set, [:byline_author, :byline_source])
      {set.byline_author, set.byline_source}
    end

    test "are the set's own values when it has them" do
      set = create_set(%{author: "Bl. Anne Catherine Emmerich", source: "Her visions"})
      add_meditation(set, %{author: "A Translator", source: "A translation"})

      assert byline(set) == {"Bl. Anne Catherine Emmerich", "Her visions"}
    end

    test "fall back to the derivation, each on its own" do
      set = create_set(%{author: "Bl. Anne Catherine Emmerich"})
      add_meditation(set, %{author: "A Translator", source: "The Dolorous Passion"})

      assert byline(set) == {"Bl. Anne Catherine Emmerich", "The Dolorous Passion"}
    end

    test "are nil when neither the set nor its meditations have anything to say" do
      assert byline(create_set()) == {nil, nil}
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
