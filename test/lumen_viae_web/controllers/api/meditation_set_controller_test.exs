defmodule LumenViaeWeb.API.MeditationSetControllerTest do
  use LumenViaeWeb.ConnCase, async: true

  alias LumenViae.Rosary

  defp create_set(attrs) do
    defaults = %{name: "Test Set", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
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
end
