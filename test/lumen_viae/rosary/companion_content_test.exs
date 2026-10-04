defmodule LumenViae.Rosary.CompanionContentTest do
  @moduledoc """
  The companion sections of the content document (`quotes`, `milestones`,
  `reminders`, `labels`, `forms`): their counts, that every string is the
  app's, and the rules the docs state, applied.

  `test/support/fixtures/app_companion_content.json` is the iOS app's own
  strings in source order, taken from the Swift by scanning each region's
  string literals (RosaryQuotes.swift, StreakMilestone.swift,
  ReminderMessages.swift, UserSettings.swift's intentions, MeditationSet.swift's
  label names, RosaryMethodsView.swift's kinds, RosaryForm.swift and the
  Scriptural Rosary's pages). A word changed here must be changed there.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Labels
  alias LumenViae.Rosary.RosaryContent.Labels, as: LabelsSection

  @fixture "test/support/fixtures/app_companion_content.json" |> File.read!() |> Jason.decode!()

  defp present(list), do: Enum.reject(list, &is_nil/1)

  describe "quotes" do
    test "are the app's twenty-one, word for word, in its order" do
      %{"items" => items} = Content.quotes()

      assert length(items) == 21

      served = Enum.flat_map(items, &present([&1["text"], &1["author"], &1["source"]]))
      assert served == @fixture["quotes"]
    end

    test "cite a source for six only, and name every author" do
      items = Content.quotes()["items"]

      assert length(Enum.filter(items, & &1["source"])) == 6
      assert Enum.all?(items, &(&1["author"] != ""))
    end

    test "are chosen by the day of the year, and after praying half the catalogue away" do
      %{"rotation" => rotation, "items" => items} = Content.quotes()
      count = length(items)

      assert rotation == %{"home_offset" => 0, "after_prayer_offset_divisor" => 2}

      home = fn day -> Enum.at(items, rem(day + rotation["home_offset"], count)) end

      after_prayer = fn day ->
        Enum.at(items, rem(day + div(count, rotation["after_prayer_offset_divisor"]), count))
      end

      # January 1 is day 1: the second quotation at home, the twelfth after praying.
      assert home.(1) == Enum.at(items, 1)
      assert after_prayer.(1) == Enum.at(items, 11)
      # The year turns over the catalogue: day 21 is back at the first.
      assert home.(21) == Enum.at(items, 0)
      # One session never shows the same line twice.
      assert Enum.all?(1..366, &(home.(&1) != after_prayer.(&1)))
    end
  end

  describe "milestones" do
    test "are the app's seven, word for word, ascending" do
      milestones = Content.milestones()

      assert Enum.map(milestones, & &1["days"]) == @fixture["milestone_days"]
      assert @fixture["milestone_days"] == [3, 7, 9, 33, 54, 100, 365]

      served = Enum.flat_map(milestones, &present([&1["meaning"], &1["icon"], &1["blessing"]]))
      assert served == @fixture["milestones"]
    end

    test "keep the icon names as the app has them" do
      assert Enum.map(Content.milestones(), & &1["icon"]) ==
               ~w(ph-number-circle-three ph-number-circle-seven ph-number-circle-nine ch-consecration lv-rosary lv-wheat ch-chi-rho)
    end

    test "name a run only some have a name for" do
      assert Enum.map(Content.milestones(), & &1["meaning"]) ==
               [
                 "a triduum",
                 "a faithful week",
                 "a novena",
                 nil,
                 "a Rosary novena",
                 nil,
                 "a year of grace"
               ]
    end

    test "fire at exactly their days, on a day's first prayer only" do
      reached = fn streak, sessions_today ->
        if sessions_today == 1, do: Enum.find(Content.milestones(), &(&1["days"] == streak))
      end

      assert %{"days" => 9} = reached.(9, 1)
      assert reached.(9, 2) == nil
      assert reached.(10, 1) == nil
      assert reached.(0, 1) == nil
    end
  end

  describe "reminders" do
    setup do
      %{reminders: Content.reminders()}
    end

    test "are the app's thirty, in five groups, word for word", %{reminders: reminders} do
      groups = reminders["groups"]

      assert Enum.map(groups, & &1["id"]) == ~w(peace habit devotion learning standard)
      assert Enum.map(groups, &length(&1["messages"])) == @fixture["reminder_group_sizes"]
      assert @fixture["reminder_group_sizes"] == [7, 7, 7, 2, 7]

      served = for g <- groups, m <- g["messages"], s <- [m["title"], m["body"]], do: s
      assert served == @fixture["reminders"]
    end

    test "hold no placeholder: each is shown as it is written", %{reminders: reminders} do
      for g <- reminders["groups"], m <- g["messages"] do
        refute m["title"] =~ ~r/[{}%]|\\\(/
        refute m["body"] =~ ~r/[{}%]|\\\(/
      end
    end

    test "fit a lock screen: titles under 35 characters, bodies under 80", %{
      reminders: reminders
    } do
      for g <- reminders["groups"], m <- g["messages"] do
        assert String.length(m["title"]) < 36, m["title"]
        assert String.length(m["body"]) < 80, m["body"]
      end
    end

    test "name the four intentions in the app's words", %{reminders: reminders} do
      intentions = reminders["intentions"]

      assert Enum.map(intentions, & &1["id"]) == ~w(peace habit devotion learning)

      served =
        Enum.map(intentions, & &1["raw_value"]) ++
          Enum.map(intentions, & &1["name"]) ++ Enum.map(intentions, & &1["detail"])

      assert served == @fixture["intentions"]
    end

    test "draw from their own group, and Learning from all of them", %{reminders: reminders} do
      groups = Map.new(reminders["intentions"], &{&1["id"], &1["groups"]})

      assert groups["peace"] == ["peace"]
      assert groups["habit"] == ["habit"]
      assert groups["devotion"] == ["devotion"]
      assert groups["learning"] == ~w(peace habit devotion learning standard)
      assert reminders["fallback_group"] == "standard"
      assert reminders["week_length"] == 7
    end

    test "choose a week as the app does", %{reminders: reminders} do
      # The documented rule, applied: the pool for the chosen intentions,
      # then seven messages from it starting at the day's offset.
      messages = Map.new(reminders["groups"], &{&1["id"], &1["messages"]})
      by_id = Map.new(reminders["intentions"], &{&1["id"], &1["groups"]})

      pool = fn chosen ->
        group_ids =
          cond do
            chosen == [] -> [reminders["fallback_group"]]
            "learning" in chosen -> by_id["learning"]
            true -> Enum.map(chosen, &hd(by_id[&1]))
          end

        pools = Enum.map(group_ids, &messages[&1])
        longest = pools |> Enum.map(&length/1) |> Enum.max()

        for index <- 0..(longest - 1), pool <- pools, index < length(pool), uniq: true do
          Enum.at(pool, index)
        end
      end

      week = fn chosen, offset ->
        pool = pool.(chosen)

        Enum.map(
          0..(reminders["week_length"] - 1),
          &Enum.at(pool, rem(offset + &1, length(pool)))
        )
      end

      # Nothing chosen: the neutral group, from its first message.
      assert hd(week.([], 0)) == hd(messages["standard"])
      assert length(pool.([])) == 7

      # Two chosen: the groups take turns, so a week hears from both.
      peace_and_devotion = pool.(["peace", "devotion"])

      assert Enum.take(peace_and_devotion, 4) ==
               [
                 hd(messages["peace"]),
                 hd(messages["devotion"]),
                 Enum.at(messages["peace"], 1),
                 Enum.at(messages["devotion"], 1)
               ]

      assert length(week.(["peace", "devotion"], 0)) == 7

      # Learning opens every group: 7 + 7 + 7 + 2 + 7 messages.
      assert length(pool.(["learning"])) == 30
      assert length(pool.(["peace", "learning"])) == 30

      # The offset walks the week forward and wraps.
      assert week.(["peace"], 7) == week.(["peace"], 0)
      assert hd(week.(["peace"], 3)) == Enum.at(messages["peace"], 3)
    end
  end

  describe "forms" do
    setup do
      forms = Content.forms()

      allowed =
        MapSet.new(
          @fixture["forms"] ++
            @fixture["forms_pages"] ++ @fixture["forms_listing"] ++ @fixture["forms_names"]
        )

      %{forms: forms, allowed: allowed}
    end

    defp texts(forms) do
      form_texts =
        for f <- forms["forms"],
            key <- ~w(name recorded_as kicker subtitle detail about),
            do: f[key]

      choice_texts =
        for c <- forms["choices"],
            text <-
              [c["title"], c["icon"]] ++ Enum.flat_map(c["options"], &[&1["name"], &1["note"]]),
            do: text

      form_texts ++
        choice_texts ++
        Enum.map(forms["row_titles"], & &1["title"]) ++ [forms["holy_audio_value"]]
    end

    test "every string is one the app has", %{forms: forms, allowed: allowed} do
      for text <- texts(forms) do
        assert MapSet.member?(allowed, text), "not in the app: #{inspect(text)}"
      end
    end

    test "name the two forms that have a name, as the app records them", %{forms: forms} do
      assert Enum.map(forms["forms"], &{&1["id"], &1["name"], &1["recorded_as"]}) == [
               {"scriptural", "The Scriptural Rosary", "Scriptural Rosary"},
               {"holy", "The Rosary Said Aloud", "The Rosary Aloud"}
             ]
    end

    test "name Audio's options for a set and for the Scriptural Rosary", %{forms: forms} do
      audio = Enum.find(forms["choices"], &(&1["id"] == "audio"))

      names = fn form ->
        for o <- audio["options"], o["form"] == form, do: {o["value"], o["name"]}
      end

      assert names.("meditation") == [{false, "Meditation Only"}, {true, "Whole Rosary"}]
      assert names.("scriptural") == [{false, "Read in Silence"}, {true, "Whole Rosary"}]

      counting = Enum.find(forms["choices"], &(&1["id"] == "counting"))

      assert Enum.map(counting["options"], &{&1["form"], &1["value"], &1["name"]}) == [
               {"any", false, "On My Rosary"},
               {"any", true, "On the Screen"}
             ]
    end

    test "say what each form's page offers, as the app does", %{forms: forms} do
      offered = Map.new(forms["offered"], &{&1["form"], {&1["when_aloud"], &1["when_silent"]}})

      assert offered["meditation"] == {["audio"], ["audio", "counting"]}
      assert offered["scriptural"] == {["audio"], ["audio", "counting"]}
      # The Rosary Said Aloud is always aloud and its beads move with the voice.
      assert offered["holy"] == {[], []}

      rows = Map.new(forms["rows"], &{&1["form"], {&1["when_aloud"], &1["when_silent"]}})

      assert rows["meditation"] == {["voice"], ["voice"]}
      assert rows["scriptural"] == {["mysteries", "voice"], ["mysteries"]}
      assert rows["holy"] == {["audio", "mysteries", "voice"], ["audio", "mysteries", "voice"]}
    end
  end

  describe "labels" do
    test "every stored label has a name, and the three rewordings are the app's" do
      section = LabelsSection.section()

      assert Enum.map(section["labels"], & &1["id"]) == Labels.vocabulary()
      assert Enum.all?(section["labels"], &(is_binary(&1["name"]) and &1["name"] != ""))

      reworded =
        for %{"id" => id, "name" => name} <- section["labels"], id != name, do: {id, name}

      # The app's dictionary, as pairs: its order is not the vocabulary's.
      app = @fixture["label_names"] |> Enum.chunk_every(2) |> Map.new(&List.to_tuple/1)

      assert Map.new(reworded) == app
      assert length(reworded) == 3
    end

    test "the four kinds are the app's, word for word" do
      served =
        Enum.flat_map(
          LabelsSection.section()["kinds"],
          &[&1["label"], &1["icon"], &1["title"], &1["description"]]
        )

      assert served == @fixture["kinds"]
    end

    test "no stored label a set could carry is missing a name" do
      for label <- Labels.vocabulary() do
        assert is_binary(Labels.display_name(label))
      end
    end
  end
end
