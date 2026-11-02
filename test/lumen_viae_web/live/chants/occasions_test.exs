defmodule LumenViaeWeb.Live.Chants.OccasionsTest do
  @moduledoc """
  The sung sets' rules as the app's ChantOccasion keeps them: tonight's
  song to Mary by the date, the order unrolled with its rounds and
  repeats, the rows a step at a time, the summary and the tiles.
  """
  use ExUnit.Case, async: true

  alias LumenViaeWeb.Components.MysteryPainting
  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Chants.Occasions

  setup_all do
    %{library: Library.load(nil)}
  end

  describe "tonight's song to Mary" do
    test "follows the season by the date", %{library: library} do
      song = &Occasions.antiphon_of_the_season(library, &1).id

      # Advent to the Purification
      assert song.(~D[2026-11-29]) == "alma_redemptoris_simple"
      assert song.(~D[2027-01-15]) == "alma_redemptoris_simple"
      # The Purification to Holy Saturday
      assert song.(~D[2027-02-02]) == "ave_regina_simple"
      assert song.(~D[2027-03-27]) == "ave_regina_simple"
      # Easter (28 March 2027) to the eve of Trinity Sunday
      assert song.(~D[2027-03-28]) == "regina_caeli_simple"
      # Then the Salve Regina to Advent
      assert song.(~D[2026-11-02]) == "salve_regina_simple"
    end

    test "Before Bed sings it after the Sub Tuum", %{library: library} do
      before_bed = Occasions.occasion(library, "before_bed")

      assert Enum.map(Occasions.unroll(before_bed, library, ~D[2026-12-10]).queue, & &1.chant.id) ==
               ["sub_tuum", "alma_redemptoris_simple"]

      assert Enum.map(Occasions.unroll(before_bed, library, ~D[2027-04-10]).queue, & &1.chant.id) ==
               ["sub_tuum", "regina_caeli_simple"]
    end
  end

  describe "unrolling" do
    test "the Rosary's rounds and repeats, each entry with its step", %{library: library} do
      set = Occasions.unroll(Occasions.occasion(library, "sung_rosary"), library, ~D[2026-11-02])

      assert length(set.queue) == 74
      assert Enum.count(set.queue, &(&1.chant.id == "ave_maria")) == 3 + 50
      assert Enum.take(set.queue, 3) |> Enum.map(& &1.origin) == [0, 1, 2]
      assert Enum.at(set.queue, 7).origin == 5
      assert List.last(set.queue).origin == 10
      assert length(set.chants) == 7

      assert set.seconds ==
               set.queue |> Enum.map(& &1.chant.duration) |> Enum.sum()

      assert Occasions.summary(set) =~ ~r/^7 chants · \d+ min$/
    end

    test "rows: a note in red, then its chants numbered with how often", %{library: library} do
      set = Occasions.unroll(Occasions.occasion(library, "sung_rosary"), library, ~D[2026-11-02])

      assert [%{kind: :rubric, text: "On the crucifix" <> _} | _] = set.rows
      chants = Enum.filter(set.rows, &(&1.kind == :chant))
      assert Enum.map(chants, & &1.number) == Enum.to_list(1..11)
      aves = Enum.find(chants, &(&1.origin == 6))
      assert aves.times == 10
      assert aves.seconds == aves.chant.duration * 10
      assert Occasions.repeats(10) == "×10"
      assert Occasions.repeats(1) == nil
    end

    test "the queue as the player reads it", %{library: library} do
      set = Occasions.unroll(Occasions.occasion(library, "visit"), library, ~D[2026-11-02])

      assert [["adoro_te", "https://" <> _, 0], ["ave_verum", _, 1], ["o_sacrum_convivium", _, 2]] =
               Jason.decode!(Occasions.entries_json(set))
    end

    test "a step this site cannot sing is left out" do
      assert Occasions.resolve(%{kind: "chant", chant_id: "nowhere"}, Library.load(nil), nil) ==
               nil

      assert Occasions.resolve(%{kind: "other"}, Library.load(nil), nil) == nil
    end
  end

  describe "the sets" do
    test "six, the tiles three around the Mass", %{library: library} do
      assert Enum.map(Occasions.all(library), & &1.id) ==
               ~w(benediction visit sung_rosary before_bed before_work for_the_dead)

      {before_mass, after_mass} = Occasions.tiles(library)
      assert Enum.map(before_mass, & &1.id) == ~w(sung_rosary benediction)
      assert Enum.map(after_mass, & &1.id) == ~w(before_bed)
    end

    test "every set's painting is on the site", %{library: library} do
      for occasion <- Occasions.all(library) do
        assert MysteryPainting.for_name(occasion.painting), "#{occasion.painting} is missing"
        assert {name, _x, _y} = Occasions.painting(occasion)
        assert name == occasion.painting
      end
    end

    test "an unknown or non-text id is no set", %{library: library} do
      assert Occasions.occasion(library, "nowhere") == nil
      assert Occasions.occasion(library, %{"x" => 1}) == nil
    end
  end
end
