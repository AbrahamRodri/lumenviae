defmodule LumenViae.Rosary.MeditationSetsTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Labels

  @valid_attrs %{name: "Test Set", category: "joyful"}

  defp create(attrs), do: Rosary.create_meditation_set(Map.merge(@valid_attrs, attrs))

  defp create!(attrs) do
    {:ok, set} = create(attrs)
    set
  end

  describe "labels" do
    test "default to an empty list when labels are not given" do
      assert create!(%{}).labels == []
    end

    test "accept vocabulary labels and preserve their order" do
      set = create!(%{labels: ["Saints", "Contemplative"]})

      assert set.labels == ["Saints", "Contemplative"]
      assert Rosary.get_meditation_set!(set.id).labels == ["Saints", "Contemplative"]
    end

    test "outside the managed vocabulary are rejected" do
      assert {:error, error} = create(%{labels: ["Saints", "saints"]})

      assert errors_on(error).labels == ["contains a label outside the managed vocabulary"]
    end

    test "beyond the maximum number are rejected" do
      too_many = Enum.take(Labels.vocabulary(), Labels.max_per_set() + 1)

      assert {:error, error} = create(%{labels: too_many})
      assert errors_on(error).labels == ["cannot have more than #{Labels.max_per_set()} labels"]
    end

    test "lose their duplicates while keeping first occurrence order" do
      assert create!(%{labels: ["Saints", "Intentions", "Saints"]}).labels ==
               ["Saints", "Intentions"]
    end

    test "given as nil are stored as an empty list" do
      assert create!(%{labels: nil}).labels == []
    end

    test "follow the same rules on an update, and can be cleared" do
      set = create!(%{labels: ["Saints"]})

      assert {:ok, updated} =
               Rosary.update_meditation_set(set, %{labels: ["Scriptural", "Saints"]})

      assert updated.labels == ["Scriptural", "Saints"]

      assert {:error, error} = Rosary.update_meditation_set(updated, %{labels: ["Invented"]})
      assert errors_on(error).labels == ["contains a label outside the managed vocabulary"]

      assert {:ok, cleared} = Rosary.update_meditation_set(updated, %{labels: []})
      assert cleared.labels == []
    end

    test "are checked by the dry run exactly as by the write" do
      refute Rosary.changeset_to_create_meditation_set(
               Map.put(@valid_attrs, :labels, ["Invented"])
             ).valid?

      assert Rosary.changeset_to_create_meditation_set(Map.put(@valid_attrs, :labels, ["Saints"])).valid?
    end
  end

  describe "create_meditation_set/1" do
    test "requires a name and a category" do
      assert {:error, error} = Rosary.create_meditation_set(%{})

      assert errors_on(error) == %{name: ["is required"], category: ["is required"]}
    end

    test "refuses a category outside the vocabulary" do
      assert {:error, error} = create(%{category: "radiant"})

      assert errors_on(error).category == ["is invalid"]
    end

    test "names a linked author that does not exist" do
      assert {:error, error} = create(%{author_id: -1})

      assert %{author_id: [_message]} = errors_on(error)
    end
  end

  describe "list_meditation_sets!/0" do
    test "is ordered by category and then by creation, whatever was edited since" do
      sorrowful = create!(%{name: "Sorrowful", category: "sorrowful"})
      first_joyful = create!(%{name: "Joyful A"})
      second_joyful = create!(%{name: "Joyful B"})

      # An update moves a row on the heap, which is what an unsorted read
      # would follow.
      {:ok, _} = Rosary.update_meditation_set(first_joyful, %{description: "Edited"})

      assert Rosary.list_meditation_sets!() |> Enum.map(& &1.id) ==
               [first_joyful.id, second_joyful.id, sorrowful.id]
    end

    test "carries the linked author, so the artwork fallback can be shown" do
      {:ok, author} = Rosary.create_author(%{name: "St. Alphonsus Liguori"})
      set = create!(%{author_id: author.id})

      assert [listed] = Rosary.list_meditation_sets!()
      assert listed.id == set.id
      assert listed.author_profile.id == author.id
    end
  end

  describe "get_meditation_set_by_name/2" do
    test "finds a name that exists once, and answers nil for none or several" do
      once = create!(%{name: "Venerable Fulton J. Sheen"})
      create!(%{name: "St. Alphonsus Liguori", category: "joyful"})
      create!(%{name: "St. Alphonsus Liguori", category: "sorrowful"})

      assert Rosary.get_meditation_set_by_name("Venerable Fulton J. Sheen").id == once.id
      assert Rosary.get_meditation_set_by_name("Nobody") == nil
      assert Rosary.get_meditation_set_by_name("St. Alphonsus Liguori") == nil
      assert Rosary.count_meditation_sets_by_name("St. Alphonsus Liguori") == 2
    end

    test "a category picks one of several, and matches the name exactly" do
      create!(%{name: "St. Alphonsus Liguori", category: "joyful"})
      sorrowful = create!(%{name: "St. Alphonsus Liguori", category: "sorrowful"})

      assert Rosary.get_meditation_set_by_name("St. Alphonsus Liguori", "sorrowful").id ==
               sorrowful.id

      assert Rosary.get_meditation_set_by_name("St. Alphonsus Liguori", "glorious") == nil
      assert Rosary.get_meditation_set_by_name("St. Alphonsus Liguori ", "sorrowful") == nil
    end
  end

  describe "delete_meditation_set/1" do
    test "takes the set's memberships with it and leaves the meditations" do
      {:ok, mystery} = Rosary.create_mystery(%{name: "M", category: "joyful", order: 1})
      {:ok, meditation} = Rosary.create_meditation(%{content: "Text.", mystery_id: mystery.id})
      set = create!(%{})
      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)

      assert {:ok, deleted} = Rosary.delete_meditation_set(set)
      assert deleted.id == set.id

      assert Rosary.count_meditation_sets() == 0
      assert [%{meditation_sets: []}] = Rosary.list_meditations_with_sets!()
    end
  end

  describe "expected_meditation_count/1" do
    test "seven sorrows sets hold seven meditations, others five" do
      assert Rosary.expected_meditation_count("seven_sorrows") == 7
      assert Rosary.expected_meditation_count("joyful") == 5
      assert Rosary.expected_meditation_count("glorious") == 5
    end
  end
end
