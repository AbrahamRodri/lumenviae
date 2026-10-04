defmodule LumenViaeWeb.JsonApi.RosaryContentMysteriesTest do
  @moduledoc """
  What a client reads of the mysteries over the APIs: the `mysteries`,
  `categories` and `verses` sections of `GET /api/v2/rosary-content` and
  GraphQL's `rosaryContent`, and the fields `GET /api/v2/mysteries` gained.
  v1's `GET /api/mysteries` does not change.

  Not async: it inserts the real mystery keys (`joyful_1`...), which other
  tests insert too.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Categories

  setup do
    {:ok, _} =
      Rosary.create_mystery(
        %{
          name: "The Annunciation",
          category: "joyful",
          order: 1,
          fruit: "Humility",
          key_verse:
            "Behold thou shalt conceive in thy womb, and shalt bring forth a son; and thou shalt call his name Jesus.",
          key_verse_reference: "Luke 1:31"
        },
        actor: admin()
      )

    :ok
  end

  test "the three sections come when asked for", %{conn: conn} do
    attributes =
      conn
      |> get_v2("/rosary-content?fields[rosary_content]=mysteries,categories,verses")
      |> v2_response(200)
      |> get_in(["data", "attributes"])

    assert Map.keys(attributes) |> Enum.sort() == ~w(categories mysteries verses)

    assert [
             %{
               "key" => "joyful_1",
               "category" => "joyful",
               "order" => 1,
               "name" => "The Annunciation",
               "fruit" => "Humility",
               "key_verse_reference" => "Luke 1:31",
               "announcement" => "The First Joyful Mystery: The Annunciation"
             } = mystery
           ] = attributes["mysteries"]

    assert Map.keys(mystery) |> Enum.sort() ==
             ~w(announcement artwork category description fruit key key_verse key_verse_reference name order scripture_reference)

    assert Enum.map(attributes["categories"], & &1["slug"]) == Categories.slugs()

    assert %{
             "slug" => "seven_sorrows",
             "mystery_labels" => ["The First Sorrow of Mary" | _],
             "hail_marys" => 7,
             "fatima_prayer" => false,
             "graces" => [_, _, _, _, _, _, _]
           } = List.last(attributes["categories"])

    assert length(attributes["verses"]) == 27

    assert %{"key" => "joyful_1", "verses" => [%{"bead" => 1, "reference" => "Luke 1:26"} | _]} =
             hd(attributes["verses"])
  end

  test "GET /api/v2/mysteries carries the key, the fruit and the key verse", %{conn: conn} do
    [mystery] =
      conn |> get_v2("/mysteries") |> v2_response(200) |> Map.fetch!("data")

    assert %{
             "key" => "joyful_1",
             "fruit" => "Humility",
             "key_verse_reference" => "Luke 1:31"
           } = mystery["attributes"]
  end

  test "a mystery's painting is null until published, on v2 and in the section", %{conn: conn} do
    [mystery] = conn |> get_v2("/mysteries") |> v2_response(200) |> Map.fetch!("data")
    assert Map.fetch!(mystery["attributes"], "artwork") == nil

    [served] =
      conn
      |> get_v2("/rosary-content?fields[rosary_content]=mysteries")
      |> v2_response(200)
      |> get_in(["data", "attributes", "mysteries"])

    assert Map.fetch!(served, "artwork") == nil
  end

  test "each category names its card's painting and crop", %{conn: conn} do
    categories =
      conn
      |> get_v2("/rosary-content?fields[rosary_content]=categories")
      |> v2_response(200)
      |> get_in(["data", "attributes", "categories"])

    assert %{
             "card_mystery_key" => "glorious_1",
             "card_focal_x" => 0.5,
             "card_focal_y" => 0.22,
             "card_artwork" => nil
           } = Enum.find(categories, &(&1["slug"] == "glorious"))

    assert %{"card_mystery_key" => nil, "card_artwork" => nil} =
             Enum.find(categories, &(&1["slug"] == "seven_sorrows"))
  end

  test "v1's GET /api/mysteries is as it was", %{conn: conn} do
    [mystery] = conn |> get("/api/mysteries") |> json_response(200) |> Map.fetch!("data")

    refute Map.has_key?(mystery, "key")
    refute Map.has_key?(mystery, "fruit")
    refute Map.has_key?(mystery, "key_verse")
    refute Map.has_key?(mystery, "artwork")
    refute Map.has_key?(mystery, "image_key")
  end

  test "GraphQL serves the same sections", %{conn: conn} do
    body =
      LumenViaeWeb.GraphqlHelpers.graphql(conn, """
      { rosaryContent {
          mysteries { key fruit keyVerse keyVerseReference announcement }
          categories { slug hailMarys fatimaPrayer graces mysteryLabels }
          verses { key verses { bead reference text } }
      } }
      """)

    refute body["errors"]
    content = get_in(body, ["data", "rosaryContent"])

    assert [%{"key" => "joyful_1", "fruit" => "Humility", "keyVerseReference" => "Luke 1:31"}] =
             content["mysteries"]

    assert length(content["categories"]) == 5
    assert content["verses"] |> Enum.flat_map(& &1["verses"]) |> length() == 249
  end
end
