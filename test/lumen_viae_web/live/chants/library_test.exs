defmodule LumenViaeWeb.Live.Chants.LibraryTest do
  @moduledoc """
  The Chant Library as the pages read it: the app's rules for shelves,
  paintings, the rows' second lines and the search, over the library in
  `priv/library/chant_library.json`.
  """
  use ExUnit.Case, async: true

  alias LumenViaeWeb.Components.MysteryPainting
  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Prayers.Book

  setup_all do
    library = Library.load(nil)
    %{library: library, names: Library.prayer_names(Book.load(nil))}
  end

  describe "paintings" do
    test "every painting the rules can name is on the site, with its credit" do
      for name <- Library.painting_names() do
        painting = MysteryPainting.for_name(name)
        assert painting, "#{name} is missing from priv/static/images/paintings"
        assert painting.title && painting.artist, "#{name} has no credit"
      end
    end

    test "a chant hangs its own scene, else its section's", %{library: library} do
      assert {"glorious_coronation", _, _} =
               Library.painting(Library.chant(library, "salve_regina_simple"))

      assert {"mass_lamb_of_god", _, _} =
               Library.painting(Library.chant(library, "kyrie_de_angelis"))
    end

    test "a section's card hangs its own, Durer's All Saints cut low" do
      assert {"luminous_baptism", _, _} = Library.section_painting("asperges")
      assert Library.section_painting("litanies") == {"feast_all_saints", 0.5, 0.85}
      assert {"mary_sistine_madonna", 0.5, 0.25} = Library.section_painting("unknown")
    end

    test "a shelf whose chants share one painting numbers them", %{library: library} do
      mass = Library.shelf(library, "mass_of_the_angels")
      assert Library.numbers_its_chants?(Library.shelf_chants(mass))

      our_lady = Library.shelf(library, "ourLady")
      refute Library.numbers_its_chants?(Library.shelf_chants(our_lady))
    end
  end

  describe "shelves and lines" do
    test "unknown and non-text ids are no shelf", %{library: library} do
      assert Library.shelf(library, "nowhere") == nil
      assert Library.shelf(library, nil) == nil
    end

    test "card titles take the names the sections are known by", %{library: library} do
      assert Library.card_title(Library.group(library, "ourLady")) == "Hymns to Our Lady"
      assert Library.card_title(Library.group(library, "benediction")) == "Benediction"
      assert Library.card_title(Library.group(library, "creed")) == "The Creed"
    end

    test "without_title drops the shelf's own name from its note" do
      assert Library.without_title("The Mass of the Angels: for feasts, and any Sunday") ==
               "For feasts, and any Sunday"

      assert Library.without_title("For the Sundays: through the year") ==
               "For the Sundays: through the year"
    end

    test "a setting reads mid-line, a name keeping its capitals" do
      chant = %{
        english_title: "Hail, Holy Queen",
        latin_title: "Salve Regina",
        setting: "Simple melody"
      }

      assert Library.setting_mid_line(chant) == "simple melody"
      assert Library.subtitle(chant) == "Hail, Holy Queen · simple melody"

      named = %{
        english_title: "Lord, have mercy",
        latin_title: "Kyrie",
        setting: "Mass of the Angels"
      }

      assert Library.setting_mid_line(named) == "Mass of the Angels"
      refute Library.says_setting?(named, ["Mass of the Angels", nil])
      assert Library.says_setting?(named, ["The Ordinary of the Mass"])

      said = %{english_title: "The Creed", latin_title: "Credo III", setting: "Credo III"}
      assert Library.setting_mid_line(said) == nil
    end

    test "lengths and summaries" do
      assert Library.duration_label(185) == "3:05"
      assert Library.duration_label(59.6) == "1:00"
      assert Library.summary([%{duration: 20}]) == "1 chant · 1 min"
      assert Library.summary([%{duration: 300}, %{duration: 330}]) == "2 chants · 11 min"
    end

    test "other settings are the chants singing the same prayer", %{library: library} do
      others = Library.other_settings(library, Library.chant(library, "salve_regina_simple"))
      assert Enum.map(others, & &1.id) == ["salve_regina_solemn"]
    end
  end

  describe "search" do
    test "titles first, accents and ligatures aside", %{library: library, names: names} do
      assert [%{id: "regina_caeli_simple"} | _] = Library.search(library, "regina coeli", names)
      assert Library.search(library, "  ", names) == []
    end

    test "by the prayer it sings, by its Prayer Book names, a work's settings together", %{
      library: library,
      names: names
    } do
      assert "gloria_patri" in (library |> Library.search("glory be", names) |> Enum.map(& &1.id))

      ids =
        library
        |> Library.search("zzqueen", %{"hail_holy_queen" => ["Zzqueen"]})
        |> Enum.map(& &1.id)

      assert ids == ["salve_regina_simple", "salve_regina_solemn"]
    end

    test "by a line of its words from three letters, each chant once", %{library: library} do
      hits = Library.search(library, "lacrimarum")
      assert "salve_regina_simple" in Enum.map(hits, & &1.id)
      assert Library.search(library, "xq") == []
      assert hits == Enum.uniq_by(hits, & &1.id)
    end
  end
end
