defmodule LumenViae.Rosary.MeditationsTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary

  @annotations [%{"offset" => 5, "seconds" => 2.0}]

  setup do
    {:ok, mystery} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1})

    %{mystery: mystery}
  end

  defp create_meditation(mystery, attrs \\ %{}) do
    defaults = %{"content" => "Old content", "mystery_id" => mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs))
    meditation
  end

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  describe "content markup guard" do
    test "rejects literal <break tags so markup can never be stored or rendered", ctx do
      attrs = %{
        "content" => ~s(Pause here <break time="1s" /> please),
        "mystery_id" => ctx.mystery.id
      }

      # The dry run and the write must agree, so both are asked.
      refute Rosary.changeset_to_create_meditation(attrs).valid?

      assert {:error, error} = Rosary.create_meditation(attrs)
      assert %{content: [message]} = errors_on(error)
      assert message =~ "<break>"
    end

    test "rejects unprocessed {pause:N} markers", ctx do
      attrs = %{"content" => "Pause here {pause:2} please", "mystery_id" => ctx.mystery.id}

      refute Rosary.changeset_to_create_meditation(attrs).valid?

      assert {:error, error} = Rosary.create_meditation(attrs)
      assert %{content: [message]} = errors_on(error)
      assert message =~ "{pause:N}"
    end

    test "rejects markup arriving in an edit", ctx do
      meditation = create_meditation(ctx.mystery)

      assert {:error, error} =
               Rosary.update_meditation(meditation, %{"content" => "Now with {pause:1}"})

      assert %{content: [_message]} = errors_on(error)
      assert Rosary.get_meditation!(meditation.id).content == "Old content"
    end

    test "accepts clean content and stores it exactly as given", ctx do
      content = "\nA meditation.  \n\nSecond paragraph.\n"

      assert Rosary.changeset_to_create_meditation(%{
               "content" => content,
               "mystery_id" => ctx.mystery.id
             }).valid?

      meditation = create_meditation(ctx.mystery, %{"content" => content})
      assert Rosary.get_meditation!(meditation.id).content == content
    end

    test "requires content and a mystery" do
      assert {:error, error} = Rosary.create_meditation(%{})

      assert errors_on(error) == %{content: ["is required"], mystery_id: ["is required"]}
    end

    test "names the mystery when it does not exist" do
      assert {:error, error} = Rosary.create_meditation(%{content: "Text.", mystery_id: -1})

      assert %{mystery_id: [_message]} = errors_on(error)
    end
  end

  describe "tts_annotations lifecycle" do
    test "keeps annotations provided together with content", ctx do
      meditation =
        create_meditation(ctx.mystery, %{
          "content" => "Fresh content",
          "tts_annotations" => @annotations
        })

      assert meditation.tts_annotations == @annotations
    end

    test "clears stale annotations when content changes without fresh ones", ctx do
      meditation = create_meditation(ctx.mystery, %{"tts_annotations" => @annotations})

      {:ok, updated} = Rosary.update_meditation(meditation, %{"content" => "Edited content"})

      assert updated.tts_annotations == []
      assert Rosary.get_meditation!(meditation.id).tts_annotations == []
    end

    test "keeps annotations when content is untouched", ctx do
      meditation = create_meditation(ctx.mystery, %{"tts_annotations" => @annotations})

      {:ok, updated} =
        Rosary.update_meditation(meditation, %{
          "author" => "New Author",
          "content" => "Old content"
        })

      assert updated.author == "New Author"
      assert updated.tts_annotations == @annotations
    end

    # An edit after the last pause leaves every offset where it was, so the
    # fresh annotations equal the old ones. They are still fresh, and must
    # not be mistaken for "none supplied" and thrown away.
    test "keeps fresh annotations that happen to equal the old ones", ctx do
      meditation = create_meditation(ctx.mystery, %{"tts_annotations" => @annotations})

      {:ok, updated} =
        Rosary.update_meditation(meditation, %{
          "content" => "Old content, with a later correction",
          "tts_annotations" => @annotations
        })

      assert updated.tts_annotations == @annotations
    end

    test "the dry run reports the same outcome as the write", ctx do
      meditation = create_meditation(ctx.mystery, %{"tts_annotations" => @annotations})

      changeset = Rosary.changeset_to_update_meditation(meditation, %{"content" => "Edited"})

      assert changeset.valid?
      assert Ash.Changeset.get_attribute(changeset, :tts_annotations) == []
    end
  end

  describe "reads" do
    test "list_meditations!/0 is oldest first, each with its mystery and narrations", ctx do
      first = create_meditation(ctx.mystery, %{"audio_url" => "a.mp3"})
      second = create_meditation(ctx.mystery)
      {:ok, _} = Rosary.record_narration(first, "female", "voices/female/a.mp3")

      assert [listed_first, listed_second] = Rosary.list_meditations!()
      assert listed_first.id == first.id
      assert listed_second.id == second.id
      assert listed_first.mystery.id == ctx.mystery.id
      assert [%{voice: "female"}] = listed_first.narrations
      assert listed_second.narrations == []
    end

    test "list_meditations_with_sets!/0 adds each meditation's sets, lowest id first", ctx do
      meditation = create_meditation(ctx.mystery)
      later = create_set()
      earlier_id_set = create_set()
      # Attached in the opposite order to their ids.
      {:ok, _} = Rosary.add_meditation_to_set(earlier_id_set.id, meditation.id, 1)
      {:ok, _} = Rosary.add_meditation_to_set(later.id, meditation.id, 1)

      assert [listed] = Rosary.list_meditations_with_sets!()
      assert Enum.map(listed.meditation_sets, & &1.id) == Enum.sort([later.id, earlier_id_set.id])
      assert listed.mystery.id == ctx.mystery.id
    end

    test "get_meditation/1 answers with a tuple, get_meditation!/1 raises a 404", ctx do
      meditation = create_meditation(ctx.mystery)

      assert {:ok, found} = Rosary.get_meditation(meditation.id)
      assert found.mystery.id == ctx.mystery.id
      assert found.narrations == []

      assert {:error, %Ash.Error.Invalid{}} = Rosary.get_meditation(-1)

      error = assert_raise Ash.Error.Invalid, fn -> Rosary.get_meditation!(-1) end
      assert Plug.Exception.status(error) == 404
    end

    test "list_taken_audio_urls/1 returns only the filenames already claimed", ctx do
      create_meditation(ctx.mystery, %{"audio_url" => "taken.mp3"})

      assert Rosary.list_taken_audio_urls(["taken.mp3", "free.mp3"]) == ["taken.mp3"]
      assert Rosary.list_taken_audio_urls([]) == []
    end
  end

  describe "delete_meditation/1" do
    test "takes the meditation's narrations and memberships with it", ctx do
      meditation = create_meditation(ctx.mystery, %{"audio_url" => "a.mp3"})
      set = create_set()
      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)
      {:ok, _} = Rosary.record_narration(meditation, "female", "voices/female/a.mp3")

      assert {:ok, deleted} = Rosary.delete_meditation(meditation)
      assert deleted.id == meditation.id

      assert Rosary.list_meditations_in_set(set.id) == []
      assert Rosary.narration_counts_by_voice() == %{}
    end
  end

  describe "set membership" do
    test "list_meditations_in_set/1 follows the join row's order, not the ids", ctx do
      first_made = create_meditation(ctx.mystery, %{"title" => "Prayed second"})
      second_made = create_meditation(ctx.mystery, %{"title" => "Prayed first"})
      set = create_set()
      {:ok, _} = Rosary.add_meditation_to_set(set.id, first_made.id, 2)
      {:ok, _} = Rosary.add_meditation_to_set(set.id, second_made.id, 1)

      assert [prayed_first, prayed_second] = Rosary.list_meditations_in_set(set.id)
      assert prayed_first.title == "Prayed first"
      assert prayed_second.title == "Prayed second"
      assert prayed_first.mystery.id == ctx.mystery.id
      assert prayed_first.narrations == []
    end

    test "next_order_in_set/1 is one past the highest order in use", ctx do
      set = create_set()
      assert Rosary.next_order_in_set(set.id) == 1

      {:ok, _} = Rosary.add_meditation_to_set(set.id, create_meditation(ctx.mystery).id, 4)
      assert Rosary.next_order_in_set(set.id) == 5
    end

    test "an order must be between one and seven", ctx do
      set = create_set()
      meditation = create_meditation(ctx.mystery)

      assert {:error, low} = Rosary.add_meditation_to_set(set.id, meditation.id, 0)
      assert errors_on(low).order == ["must be greater than 0"]

      assert {:error, high} = Rosary.add_meditation_to_set(set.id, meditation.id, 8)
      assert errors_on(high).order == ["must be less than or equal to 7"]
    end

    test "a meditation cannot be in a set twice, nor two share a position", ctx do
      set = create_set()
      meditation = create_meditation(ctx.mystery)
      other = create_meditation(ctx.mystery)
      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)

      assert {:error, twice} = Rosary.add_meditation_to_set(set.id, meditation.id, 2)
      assert "has already been taken" in List.flatten(Map.values(errors_on(twice)))

      assert {:error, clash} = Rosary.add_meditation_to_set(set.id, other.id, 1)
      assert "has already been taken" in List.flatten(Map.values(errors_on(clash)))
    end

    test "remove_meditation_from_set/2 removes that one membership and nothing else", ctx do
      set = create_set()
      other_set = create_set()
      meditation = create_meditation(ctx.mystery)
      staying = create_meditation(ctx.mystery)
      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)
      {:ok, _} = Rosary.add_meditation_to_set(set.id, staying.id, 2)
      {:ok, _} = Rosary.add_meditation_to_set(other_set.id, meditation.id, 1)

      assert :ok = Rosary.remove_meditation_from_set(set.id, meditation.id)

      assert set.id |> Rosary.list_meditations_in_set() |> Enum.map(& &1.id) == [staying.id]

      assert other_set.id |> Rosary.list_meditations_in_set() |> Enum.map(& &1.id) == [
               meditation.id
             ]

      # Removing what is not there is not an error.
      assert :ok = Rosary.remove_meditation_from_set(set.id, meditation.id)
    end
  end

  describe "error_summary/1" do
    test "reads an error the way a report prints it", ctx do
      assert {:error, error} =
               Rosary.create_meditation(%{"content" => "{pause:1}", "mystery_id" => nil})

      summary = Rosary.error_summary(error)
      assert summary =~ "mystery_id: is required"
      assert summary =~ "content: contains an unprocessed {pause:N} marker"

      changeset = Rosary.changeset_to_create_meditation(%{"mystery_id" => ctx.mystery.id})
      assert Rosary.error_summary(changeset) == "content: is required"
    end
  end
end
