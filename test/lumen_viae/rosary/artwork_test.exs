defmodule LumenViae.Rosary.ArtworkTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork

  @upload %{
    "image_key" => "sets/27/8f21c4d9e0b3a7f6.jpg",
    "image_width" => 1600,
    "image_height" => 2400,
    "image_updated_at" => ~U[2026-08-19 12:00:00Z]
  }

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Artwork Set #{System.unique_integer([:positive])}", category: "sorrowful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  defp with_artwork(set, metadata \\ %{}) do
    attrs =
      Map.merge(@upload, %{
        "image_alt" => "Christ falls beneath the cross.",
        "image_license" => "public_domain"
      })

    {:ok, set} = Rosary.update_meditation_set_artwork(set, Map.merge(attrs, metadata))
    set
  end

  describe "the managed and editable split" do
    test "cast_upload writes the key and dimensions" do
      set = with_artwork(create_set())

      assert set.image_key == "sets/27/8f21c4d9e0b3a7f6.jpg"
      assert set.image_width == 1600
      assert set.image_height == 2400
      assert set.image_updated_at == ~U[2026-08-19 12:00:00Z]
    end

    # Without this split a crafted form post could point a set at any object
    # in the bucket, or leave the stored dimensions describing a different
    # image than the one the hero is about to draw.
    test "cast_metadata cannot touch the key or the dimensions" do
      set = with_artwork(create_set())

      {:ok, updated} =
        Rosary.update_meditation_set_artwork_metadata(set, %{
          "image_key" => "sets/1/attacker.jpg",
          "image_width" => 10,
          "image_height" => 10,
          "image_artist" => "El Greco"
        })

      assert updated.image_key == "sets/27/8f21c4d9e0b3a7f6.jpg"
      assert updated.image_width == 1600
      assert updated.image_height == 2400
      assert updated.image_artist == "El Greco"
    end

    test "the ordinary set changeset cannot write artwork at all" do
      set = create_set()

      {:ok, updated} =
        Rosary.update_meditation_set(set, %{
          "name" => "Renamed",
          "image_key" => "sets/1/attacker.jpg"
        })

      assert updated.name == "Renamed"
      assert updated.image_key == nil
    end
  end

  describe "validations" do
    test "accepts a focal point anywhere in range" do
      set = create_set()

      for focal <- [0.0, 0.24, 0.5, 1.0] do
        assert {:ok, updated} =
                 Rosary.update_meditation_set_artwork_metadata(set, %{
                   "image_focal_y" => focal
                 })

        assert updated.image_focal_y == focal
      end
    end

    test "rejects a focal point outside 0..1" do
      changeset = Rosary.change_meditation_set_artwork(create_set(), %{"image_focal_y" => 1.4})

      refute changeset.valid?
      assert changeset.errors[:image_focal_y]
    end

    # Ecto replaces an empty value with the field's default, so a blank focal
    # input reads as "centred" rather than "leave it alone". That is the only
    # reading a NOT NULL column allows, and it is the right one - but it does
    # mean the admin form has to render the stored value into the input, or
    # saving an otherwise untouched form would quietly recentre the painting.
    test "a blank focal point falls back to the centre, never to null" do
      {:ok, set} =
        Rosary.update_meditation_set_artwork_metadata(create_set(), %{"image_focal_y" => 0.24})

      changeset = Rosary.change_meditation_set_artwork(set, %{"image_focal_y" => ""})

      assert changeset.valid?
      assert get_field(changeset, :image_focal_y) == 0.5
    end

    # The column is NOT NULL, so an explicit null has to fail in the
    # changeset rather than as a constraint violation at insert time.
    test "rejects an explicitly null focal point" do
      changeset = Rosary.change_meditation_set_artwork(create_set(), %{"image_focal_x" => nil})

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:image_focal_x]
    end

    test "defaults the focal point to the centre, reproducing today's fill" do
      set = create_set()

      assert set.image_focal_x == 0.5
      assert set.image_focal_y == 0.5
    end

    test "rejects a licence outside the recorded vocabulary" do
      changeset =
        Rosary.change_meditation_set_artwork(create_set(), %{"image_license" => "probably_fine"})

      refute changeset.valid?
      assert changeset.errors[:image_license]
    end

    test "accepts every licence the project records" do
      set = create_set()

      for license <- Artwork.licenses() do
        assert Rosary.change_meditation_set_artwork(set, %{"image_license" => license}).valid?
      end
    end

    test "rejects a source URL that is not a URL" do
      changeset =
        Rosary.change_meditation_set_artwork(create_set(), %{
          "image_source_url" => "metmuseum.org"
        })

      refute changeset.valid?
      assert changeset.errors[:image_source_url]
    end

    test "blanks out whitespace-only metadata so it cannot satisfy the publish gate" do
      {:ok, set} =
        Rosary.update_meditation_set_artwork_metadata(create_set(), %{
          "image_alt" => "   ",
          "image_artist" => "  El Greco  "
        })

      assert set.image_alt == nil
      assert set.image_artist == "El Greco"
    end
  end

  describe "publishable?/1" do
    test "is false until both alt text and a licence are present" do
      set = create_set()

      refute Artwork.publishable?(set)
      refute Artwork.publishable?(%{set | image_key: "sets/27/a.jpg"})

      refute Artwork.publishable?(%{
               set
               | image_key: "sets/27/a.jpg",
                 image_alt: "A description."
             })

      assert Artwork.publishable?(%{
               set
               | image_key: "sets/27/a.jpg",
                 image_alt: "A description.",
                 image_license: "public_domain"
             })
    end

    # The first upload on a set arrives with nothing but the managed fields,
    # so requiring alt text in the changeset would make it unsavable and the
    # curator could never get past it.
    test "the first upload saves even though it is not yet publishable" do
      {:ok, set} = Rosary.update_meditation_set_artwork(create_set(), @upload)

      assert set.image_key == "sets/27/8f21c4d9e0b3a7f6.jpg"
      refute Artwork.publishable?(set)
    end
  end

  describe "count_missing_artwork/0" do
    test "counts only the sets with no key" do
      before = Rosary.count_meditation_sets_missing_artwork()

      create_set()
      create_set()
      with_artwork(create_set())

      assert Rosary.count_meditation_sets_missing_artwork() == before + 2
    end
  end

  describe "alignment/1" do
    test "maps the focal point onto the three coarse alignments iOS asked for" do
      assert Artwork.alignment(0.0) == "top"
      assert Artwork.alignment(0.24) == "top"
      assert Artwork.alignment(0.5) == "center"
      assert Artwork.alignment(0.66) == "center"
      assert Artwork.alignment(0.9) == "bottom"
      assert Artwork.alignment(nil) == nil
    end
  end

  describe "object_position/2" do
    test "renders the focal point as CSS percentages" do
      assert Artwork.object_position(0.5, 0.24) == "50.0% 24.0%"
    end

    test "falls back to the centre when a focal point is missing" do
      assert Artwork.object_position(nil, nil) == "50.0% 50.0%"
    end
  end

  describe "crop/3" do
    test "a centred focal point reproduces a plain fill at every crop size" do
      for frame <- [{393, 470}, {176, 160}, {40, 40}] do
        crop = Artwork.crop({1200, 1800}, frame, {0.5, 0.5})

        assert crop.offset_x == 0.0
        assert crop.offset_y == 0.0
      end
    end

    test "fills the frame, so the drawn image never falls short of it" do
      crop = Artwork.crop({1200, 1800}, {393, 470}, {0.5, 0.24})

      assert crop.width >= 393
      assert crop.height >= 470
    end

    # The point of a normalized focal point: one value frames the same
    # painting correctly in a 470pt hero and a 40pt thumbnail, which a
    # fixed -48pt offset cannot do.
    test "shifts toward the focal point by an amount that scales with the frame" do
      hero = Artwork.crop({1200, 1800}, {393, 470}, {0.5, 0.24})
      card = Artwork.crop({1200, 1800}, {176, 160}, {0.5, 0.24})
      thumb = Artwork.crop({1200, 1800}, {40, 40}, {0.5, 0.24})

      assert hero.offset_y > card.offset_y
      assert card.offset_y > thumb.offset_y
      assert thumb.offset_y > 0
    end

    test "a focal point at the top edge pins the top of the canvas" do
      crop = Artwork.crop({1200, 1800}, {393, 470}, {0.5, 0.0})

      assert_in_delta crop.offset_y, (crop.height - 470) / 2, 0.001
    end
  end
end
