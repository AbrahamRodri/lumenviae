defmodule LumenViae.Rosary.Content.ScriptCheckTest do
  @moduledoc """
  What `priv/rosary_content/script.json` must hold, one check at a time:
  each test breaks one thing in a copy of the real templates and passes it
  through the check `LumenViae.Rosary.Content` runs when it compiles. The
  real file is never edited.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.{Categories, Content}
  alias LumenViae.Rosary.Content.ScriptCheck

  defp errors(script), do: ScriptCheck.errors(script, Content.prayer_ids(), Categories.slugs())

  defp breaking(path, fun), do: errors(update_in(Content.script(), path, fun))

  defp assert_refused(errors, words) do
    assert Enum.any?(errors, &String.contains?(&1, words)),
           "expected an error about #{inspect(words)}, got #{inspect(errors)}"
  end

  test "the real file has nothing wrong with it" do
    assert errors(Content.script()) == []
  end

  test "a script that is not an object" do
    assert errors(nil) == [~s(needs a "script" object)]
  end

  describe "the optional prayers after the Rosary" do
    test "each needs an id, a title, a short title, a detail and steps" do
      for key <- ~w(id title short_title detail) do
        ["closing_extras", Access.at(1)]
        |> breaking(&Map.delete(&1, key))
        |> assert_refused(
          "closing_extras[1] needs an id, a title, a short_title, a detail and steps"
        )
      end

      ["closing_extras", Access.at(0)]
      |> breaking(&Map.delete(&1, "steps"))
      |> assert_refused(
        "closing_extras[0] needs an id, a title, a short_title, a detail and steps"
      )

      ["closing_extras", Access.at(0)]
      |> breaking(&Map.put(&1, "steps", []))
      |> assert_refused("closing_extras[0] (holy_father) must list its steps")
    end

    test "each id once" do
      ["closing_extras"]
      |> breaking(fn [first | rest] ->
        [first, Map.put(hd(rest), "id", first["id"]) | tl(rest)]
      end)
      |> assert_refused("closing_extras names an id twice")
    end

    test "said on the Glory Be bead" do
      ["closing_extras", Access.at(2), "steps", Access.at(0)]
      |> breaking(&Map.put(&1, "bead", 8))
      |> assert_refused("closing_extras[2] (st_michael)[0] is said on bead 8, not 11")
    end
  end

  describe "the words the document shows" do
    test "headings" do
      ["headings"]
      |> breaking(&Map.delete(&1, "closing"))
      |> assert_refused("headings needs an opening and a closing")
    end

    test "the pendant's places and names" do
      ["pendant", Access.at(3)]
      |> breaking(&Map.delete(&1, "name"))
      |> assert_refused("pendant[3] needs a place and a name")

      ["pendant"]
      |> breaking(fn [first | rest] -> [first, first | rest] end)
      |> assert_refused("pendant names a place twice")
    end

    test "the strand's labels, label lines and strand labels" do
      for {key, sub, words} <- [
            {"labels", "hail_mary", "rosary.strand.labels needs our_father, hail_mary, glory_be"},
            {"label_lines", "glory_be",
             "rosary.strand.label_lines needs our_father, hail_mary, glory_be"},
            {"strand_labels", "amen", "rosary.strand.strand_labels needs our_father and amen"}
          ] do
        ["rosary", "strand", key] |> breaking(&Map.delete(&1, sub)) |> assert_refused(words)
      end

      ["chaplet", "strand"]
      |> breaking(&Map.delete(&1, "labels"))
      |> assert_refused("chaplet.strand.labels needs our_father, hail_mary, glory_be")
    end
  end

  describe "the strand" do
    test "needs its Hail Mary count" do
      ["rosary", "strand"]
      |> breaking(&Map.delete(&1, "hail_marys"))
      |> assert_refused("rosary.strand needs hail_marys as positive whole numbers")
    end

    test "says the Glory Be one past the last Hail Mary, and adds up" do
      ["chaplet", "strand"]
      |> breaking(&Map.put(&1, "glory_be_bead", 7))
      |> assert_refused("chaplet.strand.glory_be_bead must be hail_marys + 1")

      ["rosary", "strand"]
      |> breaking(&Map.put(&1, "beads", 55))
      |> assert_refused("rosary.strand.beads must be decades * decade_length + 1")

      ["rosary", "strand"]
      |> breaking(&Map.put(&1, "decade_length", 10))
      |> assert_refused("rosary.strand.decade_length must be hail_marys + 1")
    end

    test "the steps' own Glory Be beads agree with it" do
      # The Rosary's Glory Be after the decade, said on 10 instead of 11.
      ["rosary", "decade", Access.at(5)]
      |> breaking(&Map.put(&1, "bead", 10))
      |> assert_refused("rosary.decade[5] is said on bead 10, not 11")

      ["chaplet", "closing", Access.at(3)]
      |> breaking(&Map.put(&1, "bead", 11))
      |> assert_refused("chaplet.closing[3] is said on bead 11, not 8")

      ["rosary", "opening", Access.at(0)]
      |> breaking(&Map.put(&1, "bead", 1))
      |> assert_refused("rosary.opening[0] is said on bead 1, not 0")
    end
  end

  describe "the steps" do
    test "name only prayers, places and styles that exist" do
      ["rosary", "opening", Access.at(1)]
      |> breaking(&Map.put(&1, "prayer_id", "nicene_creed"))
      |> assert_refused("rosary.opening[1] names a prayer id it cannot say")

      ["rosary", "opening", Access.at(2)]
      |> breaking(&Map.put(&1, "place", "big_bead"))
      |> assert_refused("rosary.opening[2] names a place not on the pendant")

      ["chaplet", "decade", Access.at(1)]
      |> breaking(&Map.put(&1, "style", "sung"))
      |> assert_refused("chaplet.decade[1] names a style not in styles")
    end

    test "on the pendant are prayers" do
      ["rosary", "final", Access.at(0)]
      |> breaking(&Map.merge(&1, %{"kind" => "announcement", "prayer_id" => nil}))
      |> assert_refused("rosary.final[0] is on the pendant, so it must be a prayer")
    end

    test "a decade has one run said on each Hail Mary, and only a decade has one" do
      ["rosary", "decade"]
      |> breaking(
        &List.update_at(&1, 0, fn step ->
          Map.merge(step, %{"per_bead" => true, "bead" => nil})
        end)
      )
      |> assert_refused("rosary.decade needs one run of steps said on each Hail Mary, not 2")

      ["chaplet", "closing", Access.at(0)]
      |> breaking(&Map.merge(&1, %{"per_bead" => true, "bead" => nil}))
      |> assert_refused("chaplet.closing[0] is said on each Hail Mary outside a decade")
    end
  end

  test "styles name meditation" do
    ["styles"]
    |> breaking(&List.delete(&1, "meditation"))
    |> assert_refused("meditation among them")
  end

  test "every category belongs to exactly one form" do
    ["chaplet", "categories"] |> breaking(fn _ -> [] end) |> assert_refused("exactly one form")
    ["chaplet", "categories"] |> breaking(&["joyful" | &1]) |> assert_refused("exactly one form")
  end

  test "a form that is missing" do
    script = Map.delete(Content.script(), "chaplet")
    assert_refused(errors(script), "chaplet is missing")
  end
end
