defmodule LumenViae.RosaryTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Meditation

  defp create_mystery do
    {:ok, mystery} =
      Rosary.create_mystery(%{
        name: "Test Mystery #{System.unique_integer([:positive])}",
        category: "joyful",
        order: System.unique_integer([:positive])
      })

    mystery
  end

  defp create_meditation(mystery, attrs \\ %{}) do
    defaults = %{content: "Test meditation content", mystery_id: mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs))
    meditation
  end

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Test Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  defp put_in_set(set, meditation, order \\ 1) do
    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order)
    :ok
  end

  describe "archive_meditation/1 and unarchive_meditation/1" do
    test "archiving stamps archived_at and unarchiving clears it" do
      meditation = create_meditation(create_mystery())
      refute Meditation.archived?(meditation)

      {:ok, archived} = Rosary.archive_meditation(meditation)
      assert Meditation.archived?(archived)
      assert %DateTime{} = archived.archived_at

      {:ok, restored} = Rosary.unarchive_meditation(archived)
      refute Meditation.archived?(restored)
      assert restored.archived_at == nil
    end

    test "archived_at cannot be set through the regular changeset" do
      meditation = create_meditation(create_mystery())

      {:ok, updated} =
        Rosary.update_meditation(meditation, %{"archived_at" => "2026-01-01T00:00:00Z"})

      assert updated.archived_at == nil
    end
  end

  describe "visible meditation set queries" do
    test "sets containing an archived meditation are excluded everywhere" do
      mystery = create_mystery()
      visible_set = create_set()
      hidden_set = create_set()

      put_in_set(visible_set, create_meditation(mystery))

      archived = create_meditation(mystery)
      put_in_set(hidden_set, archived)
      {:ok, _} = Rosary.archive_meditation(archived)

      visible_ids = Enum.map(Rosary.list_visible_meditation_sets(), & &1.id)
      assert visible_set.id in visible_ids
      refute hidden_set.id in visible_ids

      category_ids = Enum.map(Rosary.list_visible_meditation_sets_by_category("joyful"), & &1.id)
      assert visible_set.id in category_ids
      refute hidden_set.id in category_ids

      assert Rosary.hidden_meditation_set_ids() == MapSet.new([hidden_set.id])
    end

    test "one archived meditation hides a set even when the others are active" do
      mystery = create_mystery()
      set = create_set()

      put_in_set(set, create_meditation(mystery), 1)
      archived = create_meditation(mystery)
      put_in_set(set, archived, 2)
      {:ok, _} = Rosary.archive_meditation(archived)

      refute set.id in Enum.map(Rosary.list_visible_meditation_sets(), & &1.id)
    end

    test "get_visible_meditation_set_with_ordered_meditations!/1 raises for hidden sets" do
      mystery = create_mystery()
      set = create_set()
      meditation = create_meditation(mystery)
      put_in_set(set, meditation)

      fetched = Rosary.get_visible_meditation_set_with_ordered_meditations!(set.id)
      assert fetched.id == set.id

      {:ok, _} = Rosary.archive_meditation(meditation)

      assert_raise Ecto.NoResultsError, fn ->
        Rosary.get_visible_meditation_set_with_ordered_meditations!(set.id)
      end
    end

    test "unarchiving makes the set visible again" do
      mystery = create_mystery()
      set = create_set()
      meditation = create_meditation(mystery)
      put_in_set(set, meditation)

      {:ok, archived} = Rosary.archive_meditation(meditation)
      refute set.id in Enum.map(Rosary.list_visible_meditation_sets(), & &1.id)

      {:ok, _} = Rosary.unarchive_meditation(archived)
      assert set.id in Enum.map(Rosary.list_visible_meditation_sets(), & &1.id)
      assert Rosary.hidden_meditation_set_ids() == MapSet.new()
    end

    test "sets without meditations stay visible" do
      set = create_set()
      assert set.id in Enum.map(Rosary.list_visible_meditation_sets(), & &1.id)
    end

    test "admin listing functions still return hidden sets" do
      mystery = create_mystery()
      set = create_set()
      meditation = create_meditation(mystery)
      put_in_set(set, meditation)
      {:ok, _} = Rosary.archive_meditation(meditation)

      assert set.id in Enum.map(Rosary.list_meditation_sets(), & &1.id)
      assert Rosary.get_meditation_set_with_ordered_meditations!(set.id).id == set.id
    end
  end

  describe "admin content statistics" do
    test "list_meditations_with_sets preloads mystery and sets" do
      mystery = create_mystery()
      set = create_set()
      meditation = create_meditation(mystery)
      orphan = create_meditation(mystery)
      put_in_set(set, meditation)

      by_id = Map.new(Rosary.list_meditations_with_sets(), &{&1.id, &1})

      assert by_id[meditation.id].mystery.id == mystery.id
      assert Enum.map(by_id[meditation.id].meditation_sets, & &1.id) == [set.id]
      assert by_id[orphan.id].meditation_sets == []
    end

    test "meditation counts for archive, audio, and set membership" do
      mystery = create_mystery()
      set = create_set()

      in_set_with_audio = create_meditation(mystery, %{audio_url: "audio.mp3"})
      _no_audio = create_meditation(mystery)
      archived = create_meditation(mystery)
      put_in_set(set, in_set_with_audio)
      {:ok, _} = Rosary.archive_meditation(archived)

      assert Rosary.count_archived_meditations() == 1
      # the archived meditation is excluded even though it has no audio
      assert Rosary.count_active_meditations_missing_audio() == 1
      assert Rosary.count_meditations_not_in_any_set() == 2
      assert Rosary.meditation_counts_by_mystery() == %{mystery.id => 3}
    end

    test "meditation_set_stats aggregates per-set counts" do
      mystery = create_mystery()
      set = create_set()
      empty_set = create_set()

      with_audio = create_meditation(mystery, %{audio_url: "audio.mp3"})
      plain = create_meditation(mystery)
      put_in_set(set, with_audio, 1)
      put_in_set(set, plain, 2)
      {:ok, _} = Rosary.archive_meditation(plain)

      stats = Rosary.meditation_set_stats()

      assert stats[set.id] == %{meditation_count: 2, audio_count: 1, archived_count: 1}
      refute Map.has_key?(stats, empty_set.id)
    end

    test "count_completions_last_days counts recent completions" do
      set = create_set()
      {:ok, _} = Rosary.record_completion(set.id)

      assert Rosary.count_completions_last_days(7) == 1
      assert Rosary.count_completions_last_days(30) == 1
    end
  end
end
