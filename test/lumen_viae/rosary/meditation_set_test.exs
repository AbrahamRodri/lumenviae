defmodule LumenViae.Rosary.MeditationSetTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias LumenViae.Rosary.Labels
  alias LumenViae.Rosary.MeditationSet

  @valid_attrs %{name: "Test Set", category: "joyful"}

  defp changeset(attrs) do
    MeditationSet.changeset(%MeditationSet{}, Map.merge(@valid_attrs, attrs))
  end

  describe "changeset/2 labels" do
    test "defaults to an empty list when labels are not given" do
      changeset = changeset(%{})

      assert changeset.valid?
      assert get_field(changeset, :labels) == []
    end

    test "accepts vocabulary labels and preserves their order" do
      changeset = changeset(%{labels: ["Saints", "Contemplative"]})

      assert changeset.valid?
      assert get_field(changeset, :labels) == ["Saints", "Contemplative"]
    end

    test "rejects labels outside the managed vocabulary" do
      changeset = changeset(%{labels: ["Saints", "saints"]})

      refute changeset.valid?

      assert {"contains a label outside the managed vocabulary", _} =
               changeset.errors[:labels]
    end

    test "rejects more than the maximum number of labels" do
      too_many = Enum.take(Labels.vocabulary(), Labels.max_per_set() + 1)
      changeset = changeset(%{labels: too_many})

      refute changeset.valid?
      assert {"cannot have more than " <> _, _} = changeset.errors[:labels]
    end

    test "removes duplicate labels while keeping first occurrence order" do
      changeset = changeset(%{labels: ["Saints", "Intentions", "Saints"]})

      assert changeset.valid?
      assert get_field(changeset, :labels) == ["Saints", "Intentions"]
    end

    test "normalizes nil labels to an empty list" do
      changeset = changeset(%{labels: nil})

      assert changeset.valid?
      assert get_field(changeset, :labels) == []
    end
  end
end
