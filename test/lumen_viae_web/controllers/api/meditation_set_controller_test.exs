defmodule LumenViaeWeb.API.MeditationSetControllerTest do
  use LumenViaeWeb.ConnCase, async: true

  alias LumenViae.Rosary

  defp create_set(attrs) do
    defaults = %{name: "Test Set", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  defp create_meditation_in_set(set) do
    {:ok, mystery} =
      Rosary.create_mystery(%{
        name: "Test Mystery #{System.unique_integer([:positive])}",
        category: "joyful",
        order: System.unique_integer([:positive])
      })

    {:ok, meditation} =
      Rosary.create_meditation(%{content: "Test content", mystery_id: mystery.id})

    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)
    meditation
  end

  describe "GET /api/meditation-sets?category=" do
    test "each set carries a labels array of strings", %{conn: conn} do
      labeled = create_set(%{name: "St. Louis de Montfort", labels: ["Saints", "Contemplative"]})
      unlabeled = create_set(%{name: "Plain Set"})

      data =
        conn
        |> get(~p"/api/meditation-sets?category=joyful")
        |> json_response(200)
        |> Map.fetch!("data")

      by_id = Map.new(data, &{&1["id"], &1})

      assert by_id[labeled.id]["labels"] == ["Saints", "Contemplative"]
      assert by_id[unlabeled.id]["labels"] == []
    end

    test "returns sets in creation order so chip order stays stable", %{conn: conn} do
      first = create_set(%{name: "First", labels: ["Intentions"]})
      second = create_set(%{name: "Second", labels: ["Saints"]})
      third = create_set(%{name: "Third"})

      data =
        conn
        |> get(~p"/api/meditation-sets?category=joyful")
        |> json_response(200)
        |> Map.fetch!("data")

      assert Enum.map(data, & &1["id"]) == [first.id, second.id, third.id]
    end

    test "keeps the existing summary shape alongside labels", %{conn: conn} do
      set = create_set(%{name: "Shape Check", description: "A description"})

      [summary] =
        conn
        |> get(~p"/api/meditation-sets?category=joyful")
        |> json_response(200)
        |> Map.fetch!("data")

      assert summary == %{
               "id" => set.id,
               "name" => "Shape Check",
               "category" => "joyful",
               "description" => "A description",
               "labels" => []
             }
    end
  end

  describe "GET /api/meditation-sets/:id" do
    test "includes the set's labels in order", %{conn: conn} do
      set = create_set(%{name: "Scriptural Rosary", labels: ["Scriptural", "Contemplative"]})

      data =
        conn
        |> get(~p"/api/meditation-sets/#{set.id}")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["labels"] == ["Scriptural", "Contemplative"]
      assert data["id"] == set.id
      assert data["meditations"] == []
    end

    test "returns an empty labels array for unlabeled sets", %{conn: conn} do
      set = create_set(%{name: "Unlabeled"})

      data =
        conn
        |> get(~p"/api/meditation-sets/#{set.id}")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["labels"] == []
    end
  end

  describe "archived meditations hide their sets from the API" do
    test "index excludes sets containing an archived meditation", %{conn: conn} do
      visible_set = create_set(%{name: "Visible Set"})
      hidden_set = create_set(%{name: "Hidden Set"})

      create_meditation_in_set(visible_set)
      archived = create_meditation_in_set(hidden_set)
      {:ok, _} = Rosary.archive_meditation(archived)

      for path <- [~p"/api/meditation-sets", ~p"/api/meditation-sets?category=joyful"] do
        ids =
          conn
          |> get(path)
          |> json_response(200)
          |> Map.fetch!("data")
          |> Enum.map(& &1["id"])

        assert visible_set.id in ids
        refute hidden_set.id in ids
      end
    end

    test "show returns 404 for a set containing an archived meditation", %{conn: conn} do
      set = create_set(%{name: "Hidden Set"})
      archived = create_meditation_in_set(set)
      {:ok, _} = Rosary.archive_meditation(archived)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/meditation-sets/#{set.id}")
      end
    end

    test "unarchiving restores the set in the API", %{conn: conn} do
      set = create_set(%{name: "Restored Set"})
      meditation = create_meditation_in_set(set)
      {:ok, archived} = Rosary.archive_meditation(meditation)
      {:ok, _} = Rosary.unarchive_meditation(archived)

      ids =
        conn
        |> get(~p"/api/meditation-sets")
        |> json_response(200)
        |> Map.fetch!("data")
        |> Enum.map(& &1["id"])

      assert set.id in ids

      data =
        conn
        |> get(~p"/api/meditation-sets/#{set.id}")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["id"] == set.id
    end
  end
end
