defmodule LumenViae.Rosary.MysteriesTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary

  defp create_mystery(attrs) do
    defaults = %{name: "Mystery #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, mystery} = Rosary.create_mystery(Map.merge(defaults, attrs))
    mystery
  end

  describe "list_mysteries!/0" do
    test "returns the mysteries by category, then by position within it" do
      # Created out of order on purpose: with no sort this would come back
      # in insertion order and pass by accident.
      create_mystery(%{name: "Sorrowful 2", category: "sorrowful", order: 2})
      create_mystery(%{name: "Joyful 2", category: "joyful", order: 2})
      create_mystery(%{name: "Glorious 1", category: "glorious", order: 1})
      create_mystery(%{name: "Sorrowful 1", category: "sorrowful", order: 1})
      create_mystery(%{name: "Joyful 1", category: "joyful", order: 1})

      assert Rosary.list_mysteries!() |> Enum.map(& &1.name) == [
               "Glorious 1",
               "Joyful 1",
               "Joyful 2",
               "Sorrowful 1",
               "Sorrowful 2"
             ]
    end
  end

  describe "list_mysteries_by_category!/1" do
    test "returns one category in prayer order" do
      create_mystery(%{name: "Third", category: "luminous", order: 3})
      create_mystery(%{name: "First", category: "luminous", order: 1})
      create_mystery(%{name: "Second", category: "luminous", order: 2})
      create_mystery(%{name: "Elsewhere", category: "joyful", order: 1})

      assert Rosary.list_mysteries_by_category!("luminous") |> Enum.map(& &1.name) ==
               ["First", "Second", "Third"]
    end

    test "is empty for a category nobody has heard of" do
      create_mystery(%{order: 1})

      assert Rosary.list_mysteries_by_category!("apocryphal") == []
    end
  end

  describe "get_mystery!/1" do
    test "takes the id as an integer or as the string a route carries" do
      mystery = create_mystery(%{order: 1})

      assert Rosary.get_mystery!(mystery.id).name == mystery.name
      assert Rosary.get_mystery!(to_string(mystery.id)).name == mystery.name
    end

    test "raises an error that renders as a 404 when there is no such mystery" do
      error = assert_raise Ash.Error.Invalid, fn -> Rosary.get_mystery!(-1) end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "create_mystery/1" do
    test "requires a name, a category and an order" do
      assert {:error, error} = Rosary.create_mystery(%{})

      assert errors_on(error) == %{
               name: ["is required"],
               category: ["is required"],
               order: ["is required"]
             }
    end

    test "refuses a category outside the vocabulary" do
      assert {:error, error} =
               Rosary.create_mystery(%{name: "Invented", category: "radiant", order: 1})

      assert errors_on(error).category == ["is invalid"]
    end

    test "refuses a second mystery at the same position in a category" do
      create_mystery(%{category: "glorious", order: 1})

      assert {:error, error} =
               Rosary.create_mystery(%{name: "Again", category: "glorious", order: 1})

      assert "has already been taken" in List.flatten(Map.values(errors_on(error)))
    end

    test "keeps days_prayed as the string it was given" do
      mystery = create_mystery(%{order: 1, days_prayed: "Monday, Saturday"})

      assert Rosary.get_mystery!(mystery.id).days_prayed == "Monday, Saturday"
    end
  end

  describe "update_mystery/2" do
    test "changes the fields and validates the category" do
      mystery = create_mystery(%{order: 1})

      assert {:ok, updated} = Rosary.update_mystery(mystery, %{"name" => "The Annunciation"})
      assert updated.name == "The Annunciation"

      assert {:error, error} = Rosary.update_mystery(updated, %{"category" => "radiant"})
      assert errors_on(error).category == ["is invalid"]
    end
  end

  describe "delete_mystery/1" do
    test "returns the deleted mystery" do
      mystery = create_mystery(%{order: 1})

      assert {:ok, deleted} = Rosary.delete_mystery(mystery)
      assert deleted.id == mystery.id
      assert Rosary.count_mysteries() == 0
    end

    test "refuses to delete a mystery that still has meditations" do
      mystery = create_mystery(%{order: 1})
      {:ok, _} = Rosary.create_meditation(%{content: "Text.", mystery_id: mystery.id})

      assert {:error, %Ash.Error.Invalid{}} = Rosary.delete_mystery(mystery)
      assert Rosary.count_mysteries() == 1
    end
  end
end
