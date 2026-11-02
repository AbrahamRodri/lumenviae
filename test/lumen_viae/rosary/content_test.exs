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
    ],
    "script.json" => [
      {~U[2026-10-04 02:04:00Z], "7346f03c03ccaa1c"}
    ],
    "learn.json" => [
      {~U[2026-10-04 02:00:00Z], "b9f196b7c33f956f"},
      {~U[2026-10-28 21:30:00Z], "0c83f55cfc294899"}
    ],
    "guided_rosary.json" => [
      {~U[2026-10-04 02:00:00Z], "6dfea61161cb95e7"}
    ],
    "quotes.json" => [
      {~U[2026-10-04 02:40:00Z], "c50e8791990eed94"}
    ],
    "milestones.json" => [
      {~U[2026-10-04 02:40:00Z], "bc067fe6f1791726"},
      {~U[2026-10-28 04:30:00Z], "bf72d06d8abbfd97"}
    ],
    "reminders.json" => [
      {~U[2026-10-04 02:40:00Z], "68b372df464d99f8"}
    ],
    "forms.json" => [
      {~U[2026-10-04 02:40:00Z], "a2b84f3cc5c62f33"},
      {~U[2026-10-14 16:00:00Z], "91bafdd07bfc9b87"}
    ]
  }

  # The Spanish file, outside @history because it is outside
  # Content.files/0: the English document's date is the latest of those
  # alone. Change es/prayers.json the same way.
  @spanish_history %{
    "es/prayers.json" => [
      {~U[2026-11-02 23:00:00Z], "c5fc5ae325922a61"}
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

  describe "in Spanish" do
    test "the Spanish file is dated and versioned as its history last records it" do
      assert Enum.map(Content.spanish_files(), & &1.name) == Map.keys(@spanish_history)

      for %{name: name, updated_at: updated_at, version: version} <- Content.spanish_files() do
        assert {updated_at, version} == List.last(@spanish_history[name]), """
        priv/rosary_content/#{name} changed (now #{DateTime.to_iso8601(updated_at)}, #{version}).
        Bump its updated_at and add
          {~U[#{Calendar.strftime(updated_at, "%Y-%m-%d %H:%M:%SZ")}], "#{version}"}
        at the end of its @spanish_history list.
        """
      end
    end

    test "lang reads es and its regions as Spanish, and anything else as English" do
      for lang <- ["es", "ES", "es-MX", "es_419", "es-ES"],
          do: assert(Content.language(lang) == "es")

      for lang <- [nil, "", "en", "en-US", "fr", "spanish", "e", 7],
          do: assert(Content.language(lang) == "en")
    end

    test "English is the document as it was, with no Spanish in it" do
      assert Content.prayers("en") == Content.prayers()
      assert Content.document("en") == Content.document()
      assert Content.updated_at("en") == Content.updated_at()

      for %{"title" => title, "text" => text} <- Content.prayers() do
        assert Map.keys(title) |> Enum.sort() == ["en", "la"]
        assert Map.keys(text) |> Enum.sort() == ["en", "la"]
      end
    end

    # No official Spanish text was found for these (priv/rosary_content/SOURCES.md).
    @english_only ~w(sorrows_closing_prayer)

    test "a prayer with no Spanish text is served with its English as the es" do
      for %{"id" => id, "title" => title, "text" => text} <- Content.prayers("es"),
          id in @english_only do
        assert title["es"] == title["en"]
        assert text["es"] == text["en"]
      end
    end

    test "every other prayer has its own Spanish beside the English and Latin, unchanged" do
      spanish = Content.prayers("es")

      assert Enum.map(spanish, & &1["id"]) == @prayer_ids

      for {es, en} <- Enum.zip(spanish, Content.prayers()) do
        assert Map.delete(es["title"], "es") == en["title"]
        assert Map.delete(es["text"], "es") == en["text"]
      end

      for {es, en} <- Enum.zip(spanish, Content.prayers()), es["id"] not in @english_only do
        assert es["title"]["es"] != en["title"]["en"], "#{es["id"]} has no Spanish title"
        assert es["text"]["es"] != en["text"]["en"], "#{es["id"]} has no Spanish text"

        assert Enum.all?(es["text"]["es"], &(is_binary(&1) and String.trim(&1) != "")),
               "#{es["id"]} has a blank Spanish line"
      end
    end

    test "the Spanish document has a version and a date of its own" do
      refute Content.version(Content.document("es")) == Content.version()
      assert DateTime.compare(Content.updated_at("es"), Content.updated_at()) in [:gt, :eq]
    end

    test "the spoken Rosary records no Spanish: its prayer clips say the English" do
      spanish_words =
        for p <- Content.prayers("es"),
            p["id"] not in @english_only,
            line <- p["text"]["es"],
            do: line

      for clip <- PrayerAudio.clips([:prayer]) do
        refute Enum.any?(spanish_words, &String.contains?(clip.text, &1)), "#{clip.name}"
      end
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
