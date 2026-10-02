defmodule LumenViae.RosaryTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary

  defp create_mystery do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Test Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    mystery
  end

  defp create_meditation(mystery, attrs \\ %{}) do
    defaults = %{content: "Test meditation content", mystery_id: mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs), actor: admin())
    meditation
  end

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Test Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs), actor: admin())
    set
  end

  defp put_in_set(set, meditation, order \\ 1) do
    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order, actor: admin())
    :ok
  end

  describe "archive_meditation/1 and unarchive_meditation/1" do
    test "archiving stamps archived_at and unarchiving clears it" do
      meditation = create_meditation(create_mystery())
      refute Rosary.meditation_archived?(meditation)

      {:ok, archived} = Rosary.archive_meditation(meditation, actor: admin())
      assert Rosary.meditation_archived?(archived)
      assert %DateTime{} = archived.archived_at

      {:ok, restored} = Rosary.unarchive_meditation(archived, actor: admin())
      refute Rosary.meditation_archived?(restored)
      assert restored.archived_at == nil
    end

    test "archived_at cannot be set through the regular update" do
      meditation = create_meditation(create_mystery())

      # It is not an input of that action, so the attempt is refused whole.
      assert {:error, %Ash.Error.Invalid{}} =
               Rosary.update_meditation(meditation, %{"archived_at" => "2026-01-01T00:00:00Z"},
                 actor: admin()
               )

      assert Rosary.get_meditation!(meditation.id, actor: admin()).archived_at == nil
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
      {:ok, _} = Rosary.archive_meditation(archived, actor: admin())

      visible_ids = Enum.map(Rosary.list_visible_meditation_sets!(), & &1.id)
      assert visible_set.id in visible_ids
      refute hidden_set.id in visible_ids

      category_ids = Enum.map(Rosary.list_visible_meditation_sets_by_category!("joyful"), & &1.id)
      assert visible_set.id in category_ids
      refute hidden_set.id in category_ids

      assert Rosary.hidden_meditation_set_ids(actor: admin()) == MapSet.new([hidden_set.id])
    end

    test "one archived meditation hides a set even when the others are active" do
      mystery = create_mystery()
      set = create_set()

      put_in_set(set, create_meditation(mystery), 1)
      archived = create_meditation(mystery)
      put_in_set(set, archived, 2)
      {:ok, _} = Rosary.archive_meditation(archived, actor: admin())

      refute set.id in Enum.map(Rosary.list_visible_meditation_sets!(), & &1.id)
    end

    test "get_visible_meditation_set_with_ordered_meditations!/1 raises for hidden sets" do
      mystery = create_mystery()
      set = create_set()
      meditation = create_meditation(mystery)
      put_in_set(set, meditation)

      fetched = Rosary.get_visible_meditation_set_with_ordered_meditations!(set.id)
      assert fetched.id == set.id

      {:ok, _} = Rosary.archive_meditation(meditation, actor: admin())

      error =
        assert_raise Ash.Error.Invalid, fn ->
          Rosary.get_visible_meditation_set_with_ordered_meditations!(set.id)
        end

      assert Plug.Exception.status(error) == 404
    end

    test "unarchiving makes the set visible again" do
      mystery = create_mystery()
      set = create_set()
      meditation = create_meditation(mystery)
      put_in_set(set, meditation)

      {:ok, archived} = Rosary.archive_meditation(meditation, actor: admin())
      refute set.id in Enum.map(Rosary.list_visible_meditation_sets!(), & &1.id)

      {:ok, _} = Rosary.unarchive_meditation(archived, actor: admin())
      assert set.id in Enum.map(Rosary.list_visible_meditation_sets!(), & &1.id)
      assert Rosary.hidden_meditation_set_ids(actor: admin()) == MapSet.new()
    end

    test "a set without meditations is hidden until it has one" do
      set = create_set()

      refute set.id in Enum.map(Rosary.list_visible_meditation_sets!(), & &1.id)
      assert MapSet.member?(Rosary.hidden_meditation_set_ids(actor: admin()), set.id)

      error =
        assert_raise Ash.Error.Invalid, fn ->
          Rosary.get_visible_meditation_set_with_ordered_meditations!(set.id)
        end

      assert Plug.Exception.status(error) == 404

      put_in_set(set, create_meditation(create_mystery()))

      assert set.id in Enum.map(Rosary.list_visible_meditation_sets!(), & &1.id)
      refute MapSet.member?(Rosary.hidden_meditation_set_ids(actor: admin()), set.id)
      assert Rosary.get_visible_meditation_set_with_ordered_meditations!(set.id).id == set.id
    end

    test "admin listing functions still return hidden sets" do
      mystery = create_mystery()
      set = create_set()
      meditation = create_meditation(mystery)
      put_in_set(set, meditation)
      {:ok, _} = Rosary.archive_meditation(meditation, actor: admin())

      assert set.id in Enum.map(Rosary.list_meditation_sets!(actor: admin()), & &1.id)

      assert Rosary.get_meditation_set_with_ordered_meditations!(set.id, actor: admin()).id ==
               set.id
    end
  end

  describe "admin content statistics" do
    test "list_meditations_with_sets preloads mystery and sets" do
      mystery = create_mystery()
      set = create_set()
      meditation = create_meditation(mystery)
      orphan = create_meditation(mystery)
      put_in_set(set, meditation)

      by_id = Map.new(Rosary.list_meditations_with_sets!(actor: admin()), &{&1.id, &1})

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
      {:ok, _} = Rosary.archive_meditation(archived, actor: admin())

      assert Rosary.count_archived_meditations(actor: admin()) == 1
      # Archived meditations are not counted as gaps, and neither is an
      # unnarrated one nobody can reach: only the meditation in a live set
      # with no audio would be.
      assert Rosary.public_meditation_ids_missing_audio(actor: admin()) == []
      assert Rosary.count_meditations_not_in_any_set(actor: admin()) == 1
      assert Rosary.meditation_counts_by_mystery(actor: admin()) == %{mystery.id => 3}
      assert Rosary.active_meditation_counts_by_mystery(actor: admin()) == %{mystery.id => 2}
    end

    test "missing audio counts only meditations the public can reach" do
      mystery = create_mystery()
      set = create_set()

      reachable = create_meditation(mystery)
      _orphan = create_meditation(mystery)
      put_in_set(set, reachable)

      assert Rosary.public_meditation_ids_missing_audio(actor: admin()) == [reachable.id]
    end

    test "a set hidden by an archived meditation stops reporting missing audio" do
      mystery = create_mystery()
      set = create_set()

      silent = create_meditation(mystery)
      archived = create_meditation(mystery, %{audio_url: "narrated.mp3"})
      put_in_set(set, silent, 1)
      put_in_set(set, archived, 2)

      assert Rosary.public_meditation_ids_missing_audio(actor: admin()) == [silent.id]

      {:ok, _} = Rosary.archive_meditation(archived, actor: admin())

      # The set is now hidden, so its unnarrated meditation is nobody's
      # problem until the set comes back.
      assert Rosary.public_meditation_ids_missing_audio(actor: admin()) == []
    end

    test "completions_by_day fills in the days nobody prayed" do
      set = create_set()
      {:ok, _} = Rosary.record_completion(set.id)

      series = Rosary.completions_by_day(7, actor: admin())

      assert length(series) == 7
      # Sorted with Date, not structurally: a bare Enum.sort compares the
      # struct fields one by one and puts Oct 1 before Sep 25.
      assert Enum.map(series, & &1.date) == Enum.sort(Enum.map(series, & &1.date), Date)
      assert List.last(series).date == LumenViae.CentralTime.today()
      assert Enum.sum(Enum.map(series, & &1.count)) == 1
    end

    test "completion_summary pairs each window with the one before it" do
      set = create_set()
      {:ok, _} = Rosary.record_completion(set.id)
      {:ok, _} = Rosary.record_completion(set.id)

      summary = Rosary.completion_summary(actor: admin())

      assert summary.total == 2
      assert summary.today == 2
      assert summary.last_7 == 2
      assert summary.previous_7 == 0
      assert summary.active_sets_30 == 1
    end

    test "get_completions_by_set can be windowed to a trailing period" do
      recent = create_set()
      {:ok, _} = Rosary.record_completion(recent.id)

      assert [%{set_id: id, count: 1}] = Rosary.get_completions_by_set(days: 30, actor: admin())
      assert id == recent.id
    end

    test "meditation_set_stats aggregates per-set counts" do
      mystery = create_mystery()
      set = create_set()
      empty_set = create_set()

      with_audio = create_meditation(mystery, %{audio_url: "audio.mp3"})
      plain = create_meditation(mystery)
      put_in_set(set, with_audio, 1)
      put_in_set(set, plain, 2)
      {:ok, _} = Rosary.archive_meditation(plain, actor: admin())

      stats = Rosary.meditation_set_stats(actor: admin())

      assert stats[set.id] == %{meditation_count: 2, audio_count: 1, archived_count: 1}
      refute Map.has_key?(stats, empty_set.id)
    end

    test "count_completions_last_days counts recent completions" do
      set = create_set()
      {:ok, _} = Rosary.record_completion(set.id)

      assert Rosary.count_completions_last_days(7, actor: admin()) == 1
      assert Rosary.count_completions_last_days(30, actor: admin()) == 1
    end
  end
end
