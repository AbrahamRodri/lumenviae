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

    test "carries the summary fields the picker reads", %{conn: conn} do
      set = create_set(%{name: "Shape Check", description: "A description"})

      [summary] =
        conn
        |> get(~p"/api/meditation-sets?category=joyful")
        |> json_response(200)
        |> Map.fetch!("data")

      # Asserted field by field rather than with map equality: an added key
      # is a compatible change and must not fail here. Whether a *shipped*
      # key can disappear is the contract test's job, not this one's.
      assert summary["id"] == set.id
      assert summary["name"] == "Shape Check"
      assert summary["category"] == "joyful"
      assert summary["description"] == "A description"
      assert summary["labels"] == []
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

  describe "the set byline" do
    test "the summary carries an explicit author and source", %{conn: conn} do
      set =
        create_set(%{
          name: "Emmerich",
          author: "Bl. Anne Catherine Emmerich",
          source: "The Dolorous Passion of Our Lord Jesus Christ"
        })

      summary =
        conn
        |> get(~p"/api/meditation-sets?category=joyful")
        |> json_response(200)
        |> Map.fetch!("data")
        |> Enum.find(&(&1["id"] == set.id))

      assert summary["author"] == "Bl. Anne Catherine Emmerich"
      assert summary["source"] == "The Dolorous Passion of Our Lord Jesus Christ"
    end

    test "the summary derives a byline from meditations that agree", %{conn: conn} do
      set = create_set(%{name: "Derived"})
      create_meditation_in_set(set)

      summary =
        conn
        |> get(~p"/api/meditation-sets?category=joyful")
        |> json_response(200)
        |> Map.fetch!("data")
        |> Enum.find(&(&1["id"] == set.id))

      # create_meditation_in_set/1 leaves the meditation unattributed, so
      # there is nothing to derive and nothing must be invented.
      assert summary["author"] == nil
      assert summary["source"] == nil
    end

    test "the detail carries the byline too", %{conn: conn} do
      set = create_set(%{name: "Liguori", author: "St. Alphonsus Liguori"})

      data =
        conn
        |> get(~p"/api/meditation-sets/#{set.id}")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["author"] == "St. Alphonsus Liguori"
    end
  end

  describe "artwork on both endpoints" do
    defp with_artwork(set, metadata \\ %{}) do
      attrs =
        Map.merge(
          %{
            "image_key" => "sets/#{set.id}/8f21c4d9e0b3a7f6.jpg",
            "image_width" => 1600,
            "image_height" => 2400,
            "image_alt" => "Christ falls beneath the cross on the road out of the city.",
            "image_license" => "public_domain",
            "image_focal_y" => 0.24
          },
          metadata
        )

      {:ok, set} = Rosary.update_meditation_set_artwork(set, attrs)
      set
    end

    defp summary_for(conn, set) do
      conn
      |> get(~p"/api/meditation-sets?category=joyful")
      |> json_response(200)
      |> Map.fetch!("data")
      |> Enum.find(&(&1["id"] == set.id))
    end

    defp detail_for(conn, set) do
      conn
      |> get(~p"/api/meditation-sets/#{set.id}")
      |> json_response(200)
      |> Map.fetch!("data")
    end

    test "the summary carries a stable unsigned URL the client can cache", %{conn: conn} do
      set = with_artwork(create_set(%{name: "Sheen"}))

      summary = summary_for(conn, set)

      assert summary["image_url"] ==
               "https://s3.us-east-2.amazonaws.com/lumenviae-images/sets/#{set.id}/8f21c4d9e0b3a7f6.jpg"

      refute summary["image_url"] =~ "X-Amz-Signature"
    end

    test "the summary carries the framing and the description", %{conn: conn} do
      set = with_artwork(create_set(%{name: "Sheen"}))

      summary = summary_for(conn, set)

      assert summary["image_alignment"] == "top"
      assert summary["image_focal_x"] == 0.5
      assert summary["image_focal_y"] == 0.24
      assert summary["image_width"] == 1600
      assert summary["image_height"] == 2400
      assert summary["image_alt"] =~ "Christ falls"
    end

    test "the summary carries the attribution as a nested object", %{conn: conn} do
      set =
        with_artwork(create_set(%{name: "Sheen"}), %{
          "image_title" => "Christ Carrying the Cross",
          "image_artist" => "El Greco",
          "image_year" => "c. 1580",
          "image_source_url" => "https://www.metmuseum.org/art/collection/search/436574"
        })

      assert summary_for(conn, set)["image_attribution"] == %{
               "title" => "Christ Carrying the Cross",
               "artist" => "El Greco",
               "year" => "c. 1580",
               "source_url" => "https://www.metmuseum.org/art/collection/search/436574",
               "license" => "public_domain"
             }
    end

    test "the detail carries the same block as the summary", %{conn: conn} do
      set = with_artwork(create_set(%{name: "Sheen"}))

      summary = summary_for(conn, set)
      detail = detail_for(conn, set)

      for key <- ~w(image_url image_alignment image_focal_x image_focal_y
                    image_width image_height image_alt image_attribution) do
        assert detail[key] == summary[key], "#{key} differs between the summary and the detail"
      end
    end

    # The client branches on image_url alone, so a half-populated catalogue
    # has to degrade one set at a time rather than break decoding.
    test "every artwork key is null for a set with no painting", %{conn: conn} do
      set = create_set(%{name: "Bare"})

      for payload <- [summary_for(conn, set), detail_for(conn, set)] do
        assert payload["image_url"] == nil
        assert payload["image_alignment"] == nil
        assert payload["image_focal_x"] == nil
        assert payload["image_focal_y"] == nil
        assert payload["image_width"] == nil
        assert payload["image_height"] == nil
        assert payload["image_alt"] == nil
        assert payload["image_attribution"] == nil
      end
    end

    test "artwork with no alt text is not served", %{conn: conn} do
      {:ok, set} =
        Rosary.update_meditation_set_artwork(create_set(%{name: "Undescribed"}), %{
          "image_key" => "sets/1/a.jpg",
          "image_width" => 1600,
          "image_height" => 2400,
          "image_license" => "public_domain"
        })

      assert summary_for(conn, set)["image_url"] == nil
    end

    test "artwork with no licence is not served", %{conn: conn} do
      {:ok, set} =
        Rosary.update_meditation_set_artwork(create_set(%{name: "Unprovenanced"}), %{
          "image_key" => "sets/1/a.jpg",
          "image_width" => 1600,
          "image_height" => 2400,
          "image_alt" => "A description."
        })

      assert summary_for(conn, set)["image_url"] == nil
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

    # A rendered 404, not a raised one: a hidden set now comes back through
    # the fallback controller in the same envelope as every other error.
    test "show returns 404 for a set containing an archived meditation", %{conn: conn} do
      set = create_set(%{name: "Hidden Set"})
      archived = create_meditation_in_set(set)
      {:ok, _} = Rosary.archive_meditation(archived)

      body =
        conn
        |> get(~p"/api/meditation-sets/#{set.id}")
        |> json_response(404)

      assert body == %{"error" => %{"code" => "not_found", "message" => "Not found"}}
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
