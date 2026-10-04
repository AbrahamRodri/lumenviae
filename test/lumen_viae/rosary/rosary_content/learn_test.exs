defmodule LumenViae.Rosary.RosaryContent.LearnTest do
  @moduledoc """
  The `learn` and `guided_rosary` sections: the How to Pray course and
  "Your First Rosary", transcribed from the iOS app. The guided steps are
  checked against the app's own `GuidedRosary.steps(for:)`, compiled and
  printed into `test/support/fixtures/ios_guided_rosary/steps.tsv`.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.RosaryContent.Learn

  @guidable ~w(joyful sorrowful glorious luminous)

  describe "guided_rosary" do
    test "walks the four sets of the Rosary in 75 steps each, and not the chaplet" do
      rosaries = Content.guided_rosary()["rosaries"]

      assert Enum.map(rosaries, & &1["category"]) == @guidable

      for %{"category" => category, "steps" => steps} <- rosaries do
        assert length(steps) == 75, category
      end
    end

    test "names the 61 beads of a rosary in the order the fingers travel them" do
      parts = Content.guided_rosary()["parts"]

      assert length(parts) == 61

      loop =
        for decade <- 0..4,
            bead <-
              Enum.map(0..9, &"loopSmall.#{decade}.#{&1}") ++
                if(decade < 4, do: ["loopLarge.#{decade}"], else: []),
            do: bead

      assert parts ==
               ~w(crucifix pendantLarge.0 pendantSmall.0 pendantSmall.1 pendantSmall.2 pendantLarge.1) ++
                 loop ++ ["medal"]
    end

    test "every step is the app's, field for field" do
      app_steps =
        "test/support/fixtures/ios_guided_rosary/steps.tsv"
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.reject(&String.starts_with?(&1, "#"))
        |> Enum.map(&String.split(&1, "\t"))
        |> Enum.group_by(&hd/1)

      assert Map.keys(app_steps) |> Enum.sort() == Enum.sort(@guidable)

      for %{"category" => category, "steps" => steps} <- Content.guided_rosary()["rosaries"] do
        assert length(steps) == length(app_steps[category])

        for {step,
             [^category, index, part, place, instruction, prayers, decade, announcement, closing]} <-
              Enum.zip(steps, app_steps[category]) do
          where = "#{category} step #{index}"
          assert step["part"] == part, where
          assert step["place"] == place, where
          assert step["instruction"] == instruction, where
          assert step["prayer_ids"] == String.split(prayers, ",", trim: true), where

          assert step["decade"] == if(decade == "", do: nil, else: String.to_integer(decade)),
                 where

          assert step["announcement"] == (announcement == "true"), where
          assert step["closing"] == (closing == "true"), where
        end
      end
    end

    test "keeps a place from the Our Father on the first large bead" do
      guided = Content.guided_rosary()

      for %{"steps" => steps} <- guided["rosaries"] do
        assert %{"part" => "pendantLarge.0", "prayer_ids" => ["our_father"]} =
                 Enum.at(steps, guided["first_kept_step"])
      end
    end
  end

  describe "the prayers named" do
    test "are every one of them in the prayers section" do
      learn = Content.learn()
      prayer_ids = Content.prayer_ids()

      named =
        Enum.flat_map(learn["steps"], & &1["prayer_ids"]) ++
          Enum.map(learn["prayer_counts"], & &1["prayer_id"]) ++
          Enum.flat_map(learn["lessons"], fn lesson ->
            Enum.flat_map(lesson["sections"], &(&1["prayer_ids"] || []))
          end) ++
          for(
            %{"steps" => steps} <- Content.guided_rosary()["rosaries"],
            step <- steps,
            id <- step["prayer_ids"],
            do: id
          ) ++
          for(
            shelf <- learn["shelves"],
            reading <- shelf["readings"],
            %{"kind" => "prayer", "target" => id} <- reading["doors"],
            do: id
          )

      assert named != []

      for id <- Enum.uniq(named) do
        assert id in prayer_ids, "#{id} is not one of the twelve"
      end
    end

    test "count each of the Rosary's eight prayers, in the order lesson 2 teaches them" do
      learn = Content.learn()
      [%{"prayer_ids" => order}] = Enum.at(learn["lessons"], 1)["sections"]

      assert Enum.map(learn["prayer_counts"], & &1["prayer_id"]) == order
      assert length(order) == 8
    end
  end

  describe "learn" do
    test "holds the three lessons, the ten steps, the counsel and the questions" do
      learn = Content.learn()

      assert Enum.map(learn["lessons"], &{&1["number"], &1["id"]}) ==
               [{1, "beads"}, {2, "prayers"}, {3, "mysteries"}]

      assert Enum.map(learn["steps"], & &1["number"]) == Enum.to_list(1..10)

      assert [
               %{"id" => "montfort_methods", "readings" => counsel},
               %{"id" => "rosary_questions", "readings" => questions}
             ] =
               learn["shelves"]

      assert Enum.map(counsel, & &1["id"]) == ~w(montfort_offering montfort_clauses montfort_well)
      assert length(questions) == 9

      for reading <- Enum.take(counsel, 2) do
        assert Enum.map(reading["tables"], &length(&1["rows"])) == [5, 5, 5], reading["id"]
      end
    end

    test "every door leads to a target in the vocabulary" do
      targets = Content.door_targets()

      doors =
        for shelf <- Content.learn()["shelves"],
            reading <- shelf["readings"],
            door <- reading["doors"],
            do: door

      assert length(doors) == 6

      for %{"kind" => kind, "target" => target} <- doors do
        assert target in Map.fetch!(targets, kind), "#{kind}:#{target}"
      end

      reading_ids =
        for shelf <- Content.learn()["shelves"], reading <- shelf["readings"], do: reading["id"]

      assert targets["reading"] == reading_ids
      assert targets["prayer"] == Content.prayer_ids()

      # The one kind whose targets the document does not hold
      assert targets["library"] == ~w(montfort cana)

      assert Enum.frequencies_by(doors, & &1["kind"]) ==
               %{"act" => 2, "library" => 2, "prayer" => 1, "page" => 1}
    end

    test "every section a lesson shows is one a client is told of" do
      for lesson <- Content.learn()["lessons"], section <- lesson["sections"] do
        assert section["shows"] in ~w(anatomy steps prayers categories dwell week)
      end
    end
  end

  test "both sections fit their types" do
    assert %LumenViae.Rosary.Types.RosaryLearn{} = Learn.section(:learn)
    assert %LumenViae.Rosary.Types.GuidedRosary{} = Learn.section(:guided_rosary)
  end
end
