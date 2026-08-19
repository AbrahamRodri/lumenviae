defmodule LumenViae.Rosary.VisibleSetTest do
  @moduledoc """
  `fetch_visible_meditation_set/1` is what the API reads a set through, so
  every way it can decline matters as much as the way it succeeds. The bang
  sibling is exercised through the admin LiveViews.
  """
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Visible Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  defp add_meditation(set, order, attrs \\ %{}) do
    {:ok, mystery} =
      Rosary.create_mystery(%{
        name: "Mystery #{System.unique_integer([:positive])}",
        category: "joyful",
        order: System.unique_integer([:positive])
      })

    {:ok, meditation} =
      Rosary.create_meditation(
        Map.merge(%{content: "Some content", mystery_id: mystery.id}, attrs)
      )

    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order)
    meditation
  end

  describe "fetch_visible_meditation_set/1" do
    test "returns a set with its meditations in the order it is prayed" do
      set = create_set()
      third = add_meditation(set, 3)
      first = add_meditation(set, 1)
      second = add_meditation(set, 2)

      assert {:ok, fetched} = Rosary.fetch_visible_meditation_set(set.id)
      assert Enum.map(fetched.meditations, & &1.id) == [first.id, second.id, third.id]
    end

    test "accepts the id as the string a URL segment gives it" do
      set = create_set()

      assert {:ok, fetched} = Rosary.fetch_visible_meditation_set(to_string(set.id))
      assert fetched.id == set.id
    end

    test "resolves the byline, so the caller does not have to remember to" do
      set = create_set()
      add_meditation(set, 1, %{author: "St. Alphonsus Liguori"})

      assert {:ok, fetched} = Rosary.fetch_visible_meditation_set(set.id)
      assert fetched.derived_author == "St. Alphonsus Liguori"
    end

    test "returns a set with no meditations at all" do
      set = create_set()

      assert {:ok, fetched} = Rosary.fetch_visible_meditation_set(set.id)
      assert fetched.meditations == []
    end

    test "declines a set that does not exist" do
      assert Rosary.fetch_visible_meditation_set(999_999) == {:error, :not_found}
    end

    # Ecto would raise a CastError on this, which Phoenix renders as a 500.
    test "declines an id that is not an id, rather than raising" do
      assert Rosary.fetch_visible_meditation_set("not-a-number") == {:error, :not_found}
      assert Rosary.fetch_visible_meditation_set("12abc") == {:error, :not_found}
      assert Rosary.fetch_visible_meditation_set(nil) == {:error, :not_found}
    end

    # The id column is a bigint, and a number past its range reached the
    # driver as an encoding error - a 500 with a stacktrace for a URL that is
    # only nonsense.
    test "declines a number no id could ever be, rather than letting the driver raise" do
      assert Rosary.fetch_visible_meditation_set("99999999999999999999") ==
               {:error, :not_found}

      assert Rosary.fetch_visible_meditation_set(99_999_999_999_999_999_999) ==
               {:error, :not_found}

      assert Rosary.fetch_visible_meditation_set(0) == {:error, :not_found}
      assert Rosary.fetch_visible_meditation_set(-5) == {:error, :not_found}
    end

    # Hidden has to be indistinguishable from absent, or the API leaks which
    # sets exist but are withdrawn.
    test "declines a set holding an archived meditation, exactly as if it were missing" do
      set = create_set()
      meditation = add_meditation(set, 1)
      {:ok, _} = Rosary.archive_meditation(meditation)

      assert Rosary.fetch_visible_meditation_set(set.id) == {:error, :not_found}
    end

    test "returns the set again once the meditation is unarchived" do
      set = create_set()
      meditation = add_meditation(set, 1)
      {:ok, archived} = Rosary.archive_meditation(meditation)
      {:ok, _} = Rosary.unarchive_meditation(archived)

      assert {:ok, _} = Rosary.fetch_visible_meditation_set(set.id)
    end
  end

  describe "artwork_url/1" do
    test "is nil for a set with no painting" do
      assert Rosary.artwork_url(create_set()) == nil
    end

    test "is nil for a record that has no artwork columns at all" do
      set = create_set()
      meditation = add_meditation(set, 1)

      assert Rosary.artwork_url(meditation) == nil
    end

    test "is a stable unsigned URL for a set with one" do
      {:ok, set} =
        Rosary.update_meditation_set_artwork(create_set(), %{
          "image_key" => "sets/27/8f21c4d9e0b3a7f6.jpg",
          "image_width" => 1600,
          "image_height" => 2400
        })

      url = Rosary.artwork_url(set)

      assert url =~ "/lumenviae-images/sets/27/8f21c4d9e0b3a7f6.jpg"
      refute url =~ "X-Amz-Signature"
    end
  end
end
