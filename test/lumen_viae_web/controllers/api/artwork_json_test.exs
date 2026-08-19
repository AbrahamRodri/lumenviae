defmodule LumenViaeWeb.API.ArtworkJSONTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork
  alias LumenViaeWeb.API.ArtworkJSON

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Artwork JSON #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  defp published(overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          "image_key" => "sets/27/8f21c4d9e0b3a7f6.jpg",
          "image_width" => 1600,
          "image_height" => 2400,
          "image_alt" => "Christ falls beneath the cross.",
          "image_license" => "public_domain"
        },
        overrides
      )

    {:ok, set} = Rosary.update_meditation_set_artwork(create_set(), attrs)
    set
  end

  # The reason this test exists: a key added to the populated branch but not
  # to @absent would be present on sets that have artwork and simply missing
  # on those that do not. A non-optional Swift property decoding that is a
  # hard failure, and it would only show up on a half-populated catalogue.
  test "the populated block and the absent block carry exactly the same keys" do
    populated = ArtworkJSON.data(published())
    absent = ArtworkJSON.data(create_set())

    assert Map.keys(populated) == Map.keys(absent)
    assert Map.keys(absent) == Map.keys(ArtworkJSON.absent())
  end

  test "every value in the absent block is null" do
    assert Enum.all?(ArtworkJSON.absent(), fn {_key, value} -> is_nil(value) end)
  end

  test "a record with no artwork columns at all renders the absent block" do
    assert ArtworkJSON.data(%{id: 1, name: "Not a set"}) == ArtworkJSON.absent()
  end

  describe "the publish gate" do
    test "serves artwork that has both a description and a licence" do
      assert %{image_url: url} = ArtworkJSON.data(published())
      assert is_binary(url)
    end

    test "withholds artwork with no description" do
      set = published(%{"image_alt" => nil})

      assert ArtworkJSON.data(set) == ArtworkJSON.absent()
    end

    test "withholds artwork with no licence" do
      set = published(%{"image_license" => nil})

      assert ArtworkJSON.data(set) == ArtworkJSON.absent()
    end

    test "withholds artwork whose description is only whitespace" do
      set = published(%{"image_alt" => "   "})

      assert ArtworkJSON.data(set) == ArtworkJSON.absent()
    end
  end

  describe "the attribution object" do
    test "carries every field, null where the curator left it blank" do
      set = published(%{"image_artist" => "El Greco"})

      assert ArtworkJSON.data(set).image_attribution == %{
               title: nil,
               artist: "El Greco",
               year: nil,
               source_url: nil,
               license: "public_domain"
             }
    end
  end

  describe "Artwork.license_label/1" do
    test "names every licence in the vocabulary" do
      for slug <- Artwork.licenses() do
        label = Artwork.license_label(slug)

        assert is_binary(label)
        refute label == slug, "#{slug} has no display label"
      end
    end

    test "falls back to the slug rather than rendering blank" do
      assert Artwork.license_label("something_unrecognised") == "something_unrecognised"
      assert Artwork.license_label(nil) == nil
    end
  end
end
