defmodule LumenViae.Rosary.AuthorsTest do
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary

  defp create_author(attrs \\ %{}) do
    defaults = %{name: "Author #{System.unique_integer([:positive])}"}
    {:ok, author} = Rosary.create_author(Map.merge(defaults, attrs))
    author
  end

  defp create_set(attrs) do
    defaults = %{name: "Author Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  # The fields a completed upload writes plus the two the publish gate
  # requires, so the record is servable.
  defp portrait_attrs(id) do
    %{
      "image_key" => "authors/#{id}/8f21c4d9e0b3a7f6.jpg",
      "image_width" => 1600,
      "image_height" => 2000,
      "image_alt" => "A portrait of the author.",
      "image_license" => "public_domain"
    }
  end

  defp give_portrait(author) do
    {:ok, author} = Rosary.update_author_artwork(author, portrait_attrs(author.id))
    author
  end

  describe "create_author/1" do
    test "requires a name" do
      assert {:error, error} = Rosary.create_author(%{})
      assert errors_on(error).name == ["is required"]
    end

    test "refuses a duplicate name" do
      create_author(%{name: "Venerable Fulton J. Sheen"})

      assert {:error, error} = Rosary.create_author(%{name: "Venerable Fulton J. Sheen"})
      assert errors_on(error).name == ["has already been taken"]
    end
  end

  describe "list_authors!/0" do
    test "orders by name" do
      create_author(%{name: "St. Louis de Montfort"})
      create_author(%{name: "Bl. Anne Catherine Emmerich"})

      assert ["Bl. Anne Catherine Emmerich", "St. Louis de Montfort"] =
               Rosary.list_authors!() |> Enum.map(& &1.name)
    end
  end

  describe "author artwork" do
    test "update_author_artwork writes the managed fields" do
      author = create_author() |> give_portrait()

      assert author.image_key =~ "authors/#{author.id}/"
      assert author.image_width == 1600
      assert author.image_height == 2000
    end

    test "update_author_artwork_metadata cannot reach the key or the dimensions" do
      author = create_author() |> give_portrait()

      # The key and the dimensions are not inputs of this action at all, so
      # naming them is refused outright and nothing is written.
      for managed <- [%{"image_key" => "authors/999/stolen.jpg"}, %{"image_width" => 1}] do
        assert {:error, %Ash.Error.Invalid{}} =
                 Rosary.update_author_artwork_metadata(
                   author,
                   Map.put(managed, "image_alt", "A better description.")
                 )
      end

      unchanged = Rosary.get_author!(author.id)
      assert unchanged.image_key == author.image_key
      assert unchanged.image_width == author.image_width
      assert unchanged.image_alt == author.image_alt

      {:ok, updated} =
        Rosary.update_author_artwork_metadata(author, %{"image_alt" => "A better description."})

      assert updated.image_key == author.image_key
      assert updated.image_alt == "A better description."
    end

    test "the ordinary update cannot reach any artwork column" do
      author = create_author() |> give_portrait()

      assert {:error, %Ash.Error.Invalid{}} =
               Rosary.update_author(author, %{name: "Renamed", image_alt: "Slipped in."})

      assert Rosary.get_author!(author.id).image_alt == author.image_alt
    end

    test "trims the text fields and stores a blank one as nothing" do
      author = create_author() |> give_portrait()

      {:ok, updated} =
        Rosary.update_author_artwork_metadata(author, %{
          "image_alt" => "   ",
          "image_title" => "  The Portrait  "
        })

      assert updated.image_alt == nil
      assert updated.image_title == "The Portrait"
    end

    test "validates the licence, the source URL and the focal point" do
      author = create_author() |> give_portrait()

      assert {:error, error} =
               Rosary.update_author_artwork_metadata(author, %{
                 "image_license" => "all_rights_reserved",
                 "image_source_url" => "ftp://example.com/portrait.jpg",
                 "image_focal_x" => 1.5
               })

      errors = errors_on(error)
      assert errors.image_license == ["is not one of the licences this project records"]
      assert errors.image_source_url == ["must start with http:// or https://"]
      assert errors.image_focal_x == ["must be between 0.0 and 1.0"]
    end

    test "an upload with impossible dimensions is refused" do
      author = create_author()

      assert {:error, error} =
               Rosary.update_author_artwork(author, %{
                 "image_key" => "authors/#{author.id}/aaaa.jpg",
                 "image_width" => 0,
                 "image_height" => 2000
               })

      assert errors_on(error).image_width == ["must be greater than 0"]
    end
  end

  describe "delete_author/1" do
    test "clears the link on the author's sets without touching the sets" do
      author = create_author()
      set = create_set(%{author_id: author.id})

      assert {:ok, _author} = Rosary.delete_author(author)

      reloaded = Rosary.get_meditation_set!(set.id)
      assert reloaded.author_id == nil
    end
  end

  describe "artwork_record/1" do
    test "the set's own publishable artwork wins over the author's" do
      author = create_author() |> give_portrait()
      set = create_set(%{author_id: author.id})

      {:ok, set} =
        Rosary.update_meditation_set_artwork(set, %{
          "image_key" => "sets/#{set.id}/aaaa1111bbbb2222.jpg",
          "image_width" => 1600,
          "image_height" => 2400,
          "image_alt" => "The set's own painting.",
          "image_license" => "public_domain"
        })

      {:ok, set} = Rosary.fetch_visible_meditation_set(set.id)

      assert Rosary.artwork_record(set).image_key =~ "sets/"
    end

    test "falls back to the linked author's publishable portrait" do
      author = create_author() |> give_portrait()
      set = create_set(%{author_id: author.id})

      {:ok, set} = Rosary.fetch_visible_meditation_set(set.id)

      assert Rosary.artwork_record(set).image_key == author.image_key
    end

    test "returns nil when neither the set nor the author is publishable" do
      # A portrait with no alt text and no licence is saved but not served.
      author = create_author()

      {:ok, author} =
        Rosary.update_author_artwork(author, %{
          "image_key" => "authors/#{author.id}/cccc3333dddd4444.jpg",
          "image_width" => 1600,
          "image_height" => 2000
        })

      set = create_set(%{author_id: author.id})
      {:ok, set} = Rosary.fetch_visible_meditation_set(set.id)

      assert Rosary.artwork_record(set) == nil
    end

    test "treats an unloaded author association as no author" do
      author = create_author() |> give_portrait()
      set = create_set(%{author_id: author.id})

      # The admin read does not preload the author, so the fallback must
      # quietly not apply rather than raise.
      assert Rosary.artwork_record(Rosary.get_meditation_set!(set.id)) == nil
    end
  end
end
