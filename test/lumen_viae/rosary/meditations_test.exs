defmodule LumenViae.Rosary.MeditationsTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary.Meditations

  @annotations [%{"offset" => 5, "seconds" => 2.0}]

  defp changeset(attrs), do: Meditations.change_new(attrs)
  defp changeset(attrs, meditation), do: Meditations.change(meditation, attrs)

  # The annotation-lifecycle rules only bite on an edit, so these need a
  # meditation that already exists rather than a bare struct.
  defp stored_meditation do
    {:ok, mystery} =
      LumenViae.Rosary.create_mystery(%{
        name: "The Annunciation",
        category: "joyful",
        order: 1
      })

    {:ok, meditation} =
      Meditations.create(%{
        "content" => "Old content",
        "mystery_id" => mystery.id,
        "tts_annotations" => @annotations
      })

    meditation
  end

  describe "changeset/2 content markup guard" do
    test "rejects literal <break tags so markup can never be stored or rendered" do
      changeset =
        changeset(%{"content" => ~s(Pause here <break time="1s" /> please), "mystery_id" => 1})

      refute changeset.valid?
      assert %{content: [message]} = errors_on(changeset)
      assert message =~ "<break>"
    end

    test "rejects unprocessed {pause:N} markers" do
      changeset = changeset(%{"content" => "Pause here {pause:2} please", "mystery_id" => 1})

      refute changeset.valid?
      assert %{content: [message]} = errors_on(changeset)
      assert message =~ "{pause:N}"
    end

    test "accepts clean content" do
      assert changeset(%{"content" => "A meditation.\n\nSecond paragraph.", "mystery_id" => 1}).valid?
    end
  end

  describe "changeset/2 tts_annotations lifecycle" do
    test "keeps annotations provided together with content" do
      changeset =
        changeset(%{
          "content" => "Fresh content",
          "mystery_id" => 1,
          "tts_annotations" => @annotations
        })

      assert Ecto.Changeset.get_field(changeset, :tts_annotations) == @annotations
    end

    test "clears stale annotations when content changes without fresh ones" do
      changeset = changeset(%{"content" => "Edited content"}, stored_meditation())

      assert Ecto.Changeset.get_field(changeset, :tts_annotations) == []
    end

    test "keeps annotations when content is untouched" do
      changeset =
        changeset(%{"author" => "New Author", "content" => "Old content"}, stored_meditation())

      assert Ecto.Changeset.get_field(changeset, :tts_annotations) == @annotations
    end
  end
end
