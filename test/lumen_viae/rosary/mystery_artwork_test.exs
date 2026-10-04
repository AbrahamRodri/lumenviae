defmodule LumenViae.Rosary.MysteryArtworkTest do
  @moduledoc """
  A mystery's painting and a category card's: written through the
  artwork actions, served only once published (alt text and a licence),
  and folded into the content document's version.

  Not async: the content document serves only the app's 27 keys, so these
  tests insert real ones (`joyful_1`), which other tests insert too.
  """
  use LumenViae.DataCase, async: false

  alias LumenViae.Rosary
  alias LumenViae.Rosary.RosaryContent
  alias LumenViae.Rosary.RosaryContent.Current
  alias LumenViae.Rosary.Types

  @upload %{
    image_key: "mysteries/1/0123456789abcdef.jpg",
    image_width: 1600,
    image_height: 2400,
    image_updated_at: ~U[2026-10-04 00:00:00Z]
  }

  @described %{
    image_alt: "The angel Gabriel kneels before Mary.",
    image_title: "The Annunciation",
    image_artist: "Paolo de Matteis",
    image_year: "1712",
    image_source_url: "https://commons.wikimedia.org/wiki/File:Example.jpg",
    image_license: "public_domain",
    image_focal_y: 0.3
  }

  defp mystery do
    {:ok, mystery} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1},
        actor: admin()
      )

    mystery
  end

  defp section(name) do
    RosaryContent
    |> Ash.Query.for_read(:current)
    |> Ash.Query.load(name)
    |> Ash.read_one!()
    |> Map.fetch!(name)
  end

  defp served_mystery, do: section(:mysteries) |> Enum.find(&(&1.key == "joyful_1"))
  defp served_category(slug), do: section(:categories) |> Enum.find(&(&1.slug == slug))

  describe "a mystery's painting" do
    test "is null until it is published" do
      mystery = mystery()
      assert served_mystery().artwork == nil

      {:ok, mystery} = Rosary.update_mystery_artwork(mystery, @upload, actor: admin())
      assert served_mystery().artwork == nil

      {:ok, _} =
        Rosary.update_mystery_artwork_metadata(mystery, Map.delete(@described, :image_license),
          actor: admin()
        )

      assert served_mystery().artwork == nil
    end

    test "is served with its attribution once it has alt text and a licence" do
      {:ok, mystery} = Rosary.update_mystery_artwork(mystery(), @upload, actor: admin())
      {:ok, _} = Rosary.update_mystery_artwork_metadata(mystery, @described, actor: admin())

      assert %Types.Artwork{
               url: url,
               width: 1600,
               height: 2400,
               focal_x: 0.5,
               focal_y: 0.3,
               alignment: "top",
               alt: "The angel Gabriel kneels before Mary.",
               attribution: %Types.ArtworkAttribution{
                 artist: "Paolo de Matteis",
                 year: "1712",
                 license: "public_domain"
               }
             } = served_mystery().artwork

      assert url =~ "mysteries/1/0123456789abcdef.jpg"
    end

    test "publishing it moves the document's version" do
      {:ok, mystery} = Rosary.update_mystery_artwork(mystery(), @upload, actor: admin())
      before = Current.stamp()

      {:ok, _} = Rosary.update_mystery_artwork_metadata(mystery, @described, actor: admin())

      refute Current.stamp().version == before.version
    end

    test "cannot be pointed at a key by the ordinary update" do
      mystery = mystery()

      assert {:error, %Ash.Error.Invalid{}} =
               Rosary.update_mystery(mystery, %{image_key: "elsewhere.jpg"}, actor: admin())

      {:ok, mystery} = Rosary.get_mystery(mystery.id, actor: admin())
      assert mystery.image_key == nil
    end
  end

  describe "the categories' cards" do
    test "the four Rosaries show their first mystery's painting, and the Sorrows a card of their own" do
      keys = section(:categories) |> Map.new(&{&1.slug, &1.card_mystery_key})

      assert keys == %{
               "joyful" => "joyful_1",
               "sorrowful" => "sorrowful_1",
               "glorious" => "glorious_1",
               "luminous" => "luminous_1",
               "seven_sorrows" => nil
             }
    end

    test "keep the app's focal points" do
      points = section(:categories) |> Map.new(&{&1.slug, {&1.card_focal_x, &1.card_focal_y}})

      assert points["glorious"] == {0.5, 0.22}
      assert points["seven_sorrows"] == {0.5, 0.30}
      assert points["joyful"] == {0.5, 0.5}
    end

    test "a card's painting is null until published, then served, and moves the version" do
      assert served_category("seven_sorrows").card_artwork == nil
      assert Rosary.get_category_card!("seven_sorrows", actor: admin()) == nil

      {:ok, card} = Rosary.create_category_card("seven_sorrows", actor: admin())
      {:ok, card} = Rosary.update_category_card_artwork(card, @upload, actor: admin())
      assert served_category("seven_sorrows").card_artwork == nil

      before = Current.stamp()

      {:ok, _} =
        Rosary.update_category_card_artwork_metadata(
          card,
          %{@described | image_alt: "Mary holds her dead Son.", image_artist: "Bouguereau"},
          actor: admin()
        )

      assert %Types.Artwork{alt: "Mary holds her dead Son."} =
               served_category("seven_sorrows").card_artwork

      after_publish = Current.stamp()
      refute after_publish.version == before.version
      assert DateTime.compare(after_publish.updated_at, before.updated_at) in [:gt, :eq]
    end

    test "there is at most one card a category, and only for a category there is" do
      {:ok, _} = Rosary.create_category_card("seven_sorrows", actor: admin())
      assert {:error, _} = Rosary.create_category_card("seven_sorrows", actor: admin())
      assert {:error, _} = Rosary.create_category_card("not_a_category", actor: admin())
    end

    test "the public may read a card but not write one" do
      assert {:error, %Ash.Error.Forbidden{}} = Rosary.create_category_card("seven_sorrows")
      assert Rosary.list_category_cards!() == []
    end
  end
end
