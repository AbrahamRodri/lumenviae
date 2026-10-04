defmodule LumenViae.Rosary.ContentTest do
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.{Content, PrayerAudio}

  # Every file in priv/rosary_content/, with each {updated_at, version} it
  # has been served at, oldest first. Change a content file: bump its
  # updated_at and add the new {updated_at, version} at the end of its list
  # here. The dates must increase, so a changed file is always dated.
  @history %{
    "prayers.json" => [
      {~U[2026-10-03 00:00:00Z], "6d3c6b121b21ec9e"}
    ]
  }

  @prayer_ids ~w(sign_of_cross apostles_creed our_father hail_mary glory_be fatima_prayer hail_holy_queen rosary_closing_prayer act_of_contrition sorrows_closing_prayer memorare st_michael_prayer)

  describe "the content files" do
    test "every file has a history here, and every history names a file" do
      assert Enum.map(Content.files(), & &1.name) |> Enum.sort() ==
               Map.keys(@history) |> Enum.sort()
    end

    test "every file is dated and versioned as its history last records it" do
      for %{name: name, updated_at: updated_at, version: version} <- Content.files() do
        {pinned_at, pinned_version} = List.last(@history[name])

        assert {updated_at, version} == {pinned_at, pinned_version}, """
        priv/rosary_content/#{name} changed (now #{DateTime.to_iso8601(updated_at)}, #{version}).
        Change a content file: bump its updated_at and the pinned version in
        test/lumen_viae/rosary/content_test.exs, adding
          {~U[#{Calendar.strftime(updated_at, "%Y-%m-%d %H:%M:%SZ")}], "#{version}"}
        at the end of its @history list. The date must be later than the last one there.
        """
      end
    end

    test "a file's dates increase and its version changes with each" do
      for {name, entries} <- @history,
          [{at_a, version_a}, {at_b, version_b}] <- Enum.chunk_every(entries, 2, 1, :discard) do
        assert DateTime.compare(at_a, at_b) == :lt, "#{name}: #{at_b} is not later than #{at_a}"
        refute version_a == version_b, "#{name}: #{at_b} repeats the version of #{at_a}"
      end
    end

    test "the document's date is the latest file's" do
      assert Content.updated_at() ==
               Content.files() |> Enum.map(& &1.updated_at) |> Enum.max(DateTime)
    end
  end

  describe "prayers" do
    test "the twelve prayers, in the order they are said" do
      assert Content.prayer_ids() == @prayer_ids
      assert Enum.map(Content.prayers(), & &1["id"]) == @prayer_ids
    end

    test "the spoken Rosary says the same prayers, in the same order" do
      assert PrayerAudio.prayer_ids() == @prayer_ids
    end

    test "each prayer's English and Latin have the same number of lines" do
      for %{"id" => id, "text" => %{"en" => en, "la" => la}} <- Content.prayers() do
        assert length(en) == length(la), "#{id}: #{length(en)} English lines, #{length(la)} Latin"

        assert Enum.all?(en ++ la, &(is_binary(&1) and String.trim(&1) != "")),
               "#{id} has a blank line"
      end
    end

    test "each prayer has a title in both languages and a known group" do
      for %{"id" => id, "group" => group, "title" => %{"en" => en, "la" => la}} <-
            Content.prayers() do
        assert group in Content.groups(), "#{id}'s group #{group}"
        assert en != "" and la != ""
      end

      groups = Map.new(Content.prayers(), &{&1["id"], &1["group"]})

      assert Enum.filter(@prayer_ids, &(groups[&1] == "chaplet")) ==
               ~w(act_of_contrition sorrows_closing_prayer)

      assert Enum.filter(@prayer_ids, &(groups[&1] == "after")) == ~w(memorare st_michael_prayer)
    end

    test "a rubric stays in its brackets, in both languages" do
      closing = Content.prayer("rosary_closing_prayer")

      assert hd(closing["text"]["en"]) == "[Let us pray.]"
      assert hd(closing["text"]["la"]) == "[Oremus.]"
    end

    test "a prayer is found by its id" do
      assert %{"title" => %{"en" => "The Hail Mary", "la" => "Ave Maria"}} =
               Content.prayer("hail_mary")

      assert Content.prayer("ave_regina") == nil
    end
  end

  describe "version/1" do
    test "is short, and the same every time for the same content" do
      assert Content.version() =~ ~r/^[0-9a-f]{16}$/
      assert Content.version() == Content.version()
      assert Content.version(Content.document()) == Content.version()
    end

    test "changes when one word of one prayer changes" do
      document =
        update_in(
          Content.document(),
          ["prayers", Access.at(3), "text", "en", Access.at(0)],
          fn line ->
            String.replace(line, "full of grace", "full of graces")
          end
        )

      assert get_in(document, ["prayers", Access.at(3), "id"]) == "hail_mary"
      refute Content.version(document) == Content.version()
    end

    test "changes when a line is broken differently, even with the same words" do
      document =
        update_in(Content.document(), ["prayers", Access.at(4), "text", "en"], fn [a, b, c] ->
          [a <> " " <> b, c]
        end)

      refute Content.version(document) == Content.version()
    end

    test "changes when the prayers are reordered" do
      document = update_in(Content.document(), ["prayers"], &Enum.reverse/1)

      refute Content.version(document) == Content.version()
    end
  end
end
