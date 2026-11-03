defmodule LumenViaeWeb.Live.Explore.SearchTest do
  @moduledoc """
  The one search's rules, as the app's `AppSearch`: the folding, how close
  a name answers, the best match and the sections' order. The Prayer Book
  and the Chant Library are the ones in `priv/library/`.
  """
  use LumenViae.DataCase, async: true

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Explore.Search
  alias LumenViaeWeb.Live.Prayers.Book

  @date ~D[2026-11-02]

  setup do
    book = Book.load(nil)
    library = Library.load(nil)

    %{
      sources: %{
        book: book,
        library: library,
        prayer_names: Library.prayer_names(book),
        mysteries: [],
        sets: [],
        pages: Search.pages(@date)
      }
    }
  end

  describe "closeness/2" do
    test "ranks the name itself, its start, a word's start, then anywhere in it" do
      assert Search.closeness("Salve Regina", "salve regina") == :exact
      assert Search.closeness("Salve Regina", "salve") == :start
      assert Search.closeness("Hail, Holy Queen", "holy") == :word_start
      assert Search.closeness("Memorare", "mora") == :within
      assert Search.closeness("Memorare", "joseph") == :none
    end

    test "folds case, accents and the Latin ligatures, as the app's SearchText does" do
      assert Search.closeness("Regina Cæli", "regina coeli") == :exact
      assert Search.closeness("Ave María", "AVE MARIA") == :exact
      assert Search.needle("  Pâter ") == "pater"
    end
  end

  describe "results/3" do
    test "nothing typed finds nothing", %{sources: sources} do
      assert Search.empty?(Search.results("   ", sources, @date))
    end

    test "a door found by name is the best match; found by its words alone, a row", %{
      sources: sources
    } do
      results = Search.results("hours of prayer", sources, @date)

      assert {:page, %{id: "office", path: "/hours"}} = results.best
      assert hd(Search.found_kinds(results)) == :pages

      results = Search.results("breviary", sources, @date)

      assert results.best == nil
      assert [%{kind: :pages, hits: [{:page, %{id: "office"}}]}] = results.sections
    end

    test "the best match leaves its own section, and its chip stands first", %{sources: sources} do
      results = Search.results("before mass", sources, @date)

      assert {:order, %{id: "before_mass"}} = results.best

      for section <- results.sections, hit <- section.hits do
        refute Search.id(hit) == "order:before_mass"
      end

      assert hd(Search.found_kinds(results)) == :prayers
      assert Search.count(results, :prayers) >= 1
    end

    test "finds a prayer and a chant by their Latin, accents aside", %{sources: sources} do
      for query <- ["Pater", "PÁTER"] do
        results = Search.results(query, sources, @date)
        ids = results |> all_hits() |> Enum.map(&Search.id/1)

        assert "prayer:our_father" in ids
        assert "chant:pater_noster" in ids
      end
    end

    test "sections stand in Explore's order", %{sources: sources} do
      results = Search.results("ave", sources, @date)
      kinds = Enum.map(results.sections, & &1.kind)

      assert kinds == Enum.filter(Search.kinds(), &(&1 in kinds))
    end
  end

  describe "mystery_hits/2" do
    test "a devotion by its name stands before a mystery by its own" do
      agony = %{name: "The Agony in the Garden", category: "sorrowful", order: 1}
      named = %{name: "The Sorrowful Way", category: "sorrowful", order: 2}

      assert Search.mystery_hits("sorrowful", [agony, named]) == [
               {:mysteries, "sorrowful"},
               {:mystery, named}
             ]

      assert Search.mystery_hits("agony", [agony]) == [{:mystery, agony}]
    end

    test "a row no devotion counts is no mystery" do
      fixture = %{name: "Fixture Mystery 7", category: "joyful", order: 1_007}

      assert Search.mystery_hits("fixture", [fixture]) == []
    end
  end

  describe "set_matches?/2" do
    test "by name, author, devotion and the label's shown word" do
      set = %{
        name: "Inside the Scene",
        author: "Pope St. John Paul II",
        source: nil,
        category: "luminous",
        labels: []
      }

      assert Search.set_matches?(set, "scene")
      assert Search.set_matches?(set, "john paul")
      assert Search.set_matches?(set, "luminous mysteries")
      refute Search.set_matches?(set, "joyful")
      assert Search.set_note(set) == "Pope St. John Paul II · Luminous Mysteries"
    end
  end

  defp all_hits(results),
    do: List.wrap(results.best) ++ Enum.flat_map(results.sections, & &1.hits)
end
