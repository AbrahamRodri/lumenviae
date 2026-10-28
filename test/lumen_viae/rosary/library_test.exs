defmodule LumenViae.Rosary.LibraryTest do
  @moduledoc """
  The Prayer Book, the Chant Library, the Consecration and True Devotion as
  `LumenViae.Rosary.Library` holds them: each file dated and versioned as its history records, and
  what `LumenViae.Rosary.Library.Check` refuses.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.Library.Check
  alias LumenViae.Rosary.Library.Section

  # The stand-in chant's files, as a library file names them.
  @sha "3d83eac83eca27c02e9c565e8b8e50a4a9fff7e55c66ce967489cd4bcaaa9bfe"
  @score_sha "8748a1058c7c12afcabf9907ac73228d90bed77f0596a4b8ddde475d23f8e441"
  @base "https://s3.us-east-2.amazonaws.com/lumenviae-images"

  # Every file in priv/library/, with each {updated_at, version} it has
  # had, oldest first. Changing a file without dating it fails the build:
  # bump its updated_at and add the new {updated_at, version} at the end of
  # its list. `mix lumen_viae.upload_chants` dates chant_library.json
  # itself when it rewrites it.
  @history %{
    "prayer_book.json" => [
      {~U[2026-10-14 02:51:54Z], "63167a494d1c4b44"},
      {~U[2026-10-14 03:14:56Z], "f16e6e8bb9b60649"}
    ],
    "chant_library.json" => [
      {~U[2026-10-14 02:17:43Z], "46475d99fa86b019"}
    ],
    "consecration.json" => [
      {~U[2026-10-28 02:30:43Z], "fc067fd951512d2c"}
    ],
    "true_devotion.json" => [
      {~U[2026-10-28 05:30:00Z], "3a98bd835108c60c"}
    ]
  }

  describe "the files" do
    test "every file has a history here, and every history names a file" do
      assert Library.files() |> Enum.map(& &1.name) |> Enum.sort() ==
               Map.keys(@history) |> Enum.sort()
    end

    test "every file is dated and versioned as its history last records it" do
      for %{name: name, updated_at: updated_at, version: version} <- Library.files() do
        {pinned_at, pinned_version} = List.last(@history[name])

        assert {updated_at, version} == {pinned_at, pinned_version}, """
        priv/library/#{name} changed (now #{DateTime.to_iso8601(updated_at)}, #{version}).
        Change a library file: bump its updated_at and add
          {~U[#{Calendar.strftime(updated_at, "%Y-%m-%d %H:%M:%SZ")}], "#{version}"}
        at the end of its @history list. The date must be later than the last one there.
        """
      end
    end

    test "each history moves forward: a later date, a new version" do
      for {name, entries} <- @history,
          [{at_a, v_a}, {at_b, v_b}] <- Enum.chunk_every(entries, 2, 1, :discard) do
        assert DateTime.compare(at_b, at_a) == :gt, "#{name}: #{at_b} is not after #{at_a}"
        assert v_a != v_b, "#{name}: a new date with the same version"
      end
    end

    test "a version is 16 lowercase hex characters, fingerprinting the sections" do
      for document <- Library.documents() do
        %{version: version} = Library.stamp(document)

        assert version =~ ~r/\A[0-9a-f]{16}\z/
        assert version == Content.version(Library.sections(document))
      end
    end

    test "the version changes when a word does, and only then" do
      sections = Library.sections(:prayer_book)
      %{version: version} = Library.stamp(:prayer_book)

      assert Content.version(sections) == version

      [first | rest] = sections["prayers"]
      changed = %{sections | "prayers" => [%{first | "title" => first["title"] <> "."} | rest]}

      refute Content.version(changed) == version
    end

    test "the files hold what the apps have printed: 18 chapters, 104 chants, 34 days, 13 chapters" do
      assert length(Library.sections(:prayer_book)["chapters"]) == 18
      assert length(Library.sections(:chant_library)["chants"]) == 104
      assert length(Library.sections(:consecration)["days"]) == 34

      true_devotion = Library.sections(:true_devotion)
      assert length(true_devotion["chapters"]) == 13
      assert length(Enum.flat_map(true_devotion["chapters"], & &1["paragraphs"])) == 376
    end

    test "every section is served exactly as its file holds it" do
      for document <- Library.documents(), {name, held} <- Library.sections(document) do
        assert Section.plain(Library.served(document, name)) == held, "#{document} #{name}"
      end
    end

    test "every chant file is on the public assets bucket" do
      # Moving the files is a decision: change this with the upload.
      assert Library.asset_base() == "https://s3.us-east-2.amazonaws.com/lumenviae-images"

      for chant <- Library.sections(:chant_library)["chants"],
          file <- [chant["audio"] | chant["score"]] do
        assert String.starts_with?(file["url"], Library.asset_base() <> "/chants/")
      end
    end

    test "text a type would change is refused, naming its section" do
      assert Library.cast_errors(:chant_library, library()) == []

      [page] = hd(library()["chants"])["score"]
      padded = update_chant(library(), "score", [%{page | "caption" => " Salve Regina"}])

      assert [message] = Library.cast_errors(:chant_library, padded)
      assert message =~ "chants would not be served as written"
      assert message =~ "salve_regina_simple"

      assert [message] =
               Library.cast_errors(:prayer_book, update_prayer(book(), "title", "Sub tuum "))

      assert message =~ "prayers would not be served as written"
      assert message =~ "sub_tuum"
    end

    test "a chant names only prayers the book holds" do
      prayer_ids = MapSet.new(Library.prayer_ids())

      for chant <- Library.sections(:chant_library)["chants"], id <- chant["prayer_ids"] do
        assert MapSet.member?(prayer_ids, id), "#{chant["id"]} names #{id}"
      end
    end
  end

  describe "the Prayer Book's check" do
    test "the file as it is passes" do
      assert Check.prayer_book_errors(Library.sections(:prayer_book)) == []
    end

    test "refuses a repeated prayer id" do
      book = book()
      book = %{book | "prayers" => book["prayers"] ++ [hd(book["prayers"])]}

      assert book_errors(book) =~ ~s(the prayer id "sub_tuum" is repeated)
    end

    test "refuses Latin that does not pair with the English line for line" do
      assert book_errors(update_prayer(book(), "latin", "One line only")) =~
               "sub_tuum has 2 English lines and 1 Latin"
    end

    test "allows a prayer with no Latin" do
      assert Check.prayer_book_errors(update_prayer(book(), "latin", nil)) == []
    end

    test "refuses a missing title and a field that is neither text nor null" do
      book = update_prayer(update_prayer(book(), "title", ""), "origin", 3)

      assert book_errors(book) =~ "title is required text"
      assert book_errors(book) =~ "origin is text or null"
    end

    test "refuses a chapter naming a prayer that does not exist" do
      book = update_chapter(book(), "prayer_ids", ["sub_tuum", "memorare", "nowhere"])

      assert book_errors(book) =~ ~s(names the prayer "nowhere")
    end

    test "refuses a chapter whose prayer_ids are not its sections' union, in order" do
      book = update_chapter(book(), "prayer_ids", ["memorare", "sub_tuum"])

      assert book_errors(book) =~ "its prayer_ids are not its sections' prayers"
    end

    test "allows a prayer under two sections, once in the chapter" do
      sections = [
        %{"title" => "One", "prayer_ids" => ["sub_tuum"]},
        %{"title" => "Two", "prayer_ids" => ["memorare", "sub_tuum"]}
      ]

      assert Check.prayer_book_errors(update_chapter(book(), "sections", sections)) == []
    end

    test "refuses a chapter with no sections list" do
      book = %{book() | "chapters" => [Map.delete(hd(book()["chapters"]), "sections")]}

      assert book_errors(book) =~ "it needs a list of sections"
    end

    test "refuses a chapter with an empty sections list" do
      assert book_errors(update_chapter(book(), "sections", [])) =~
               "it needs at least one section"
    end

    test "refuses a repeated chapter id" do
      book = book()
      book = %{book | "chapters" => book["chapters"] ++ book["chapters"]}

      assert book_errors(book) =~ ~s(the chapter id "our_lady" is repeated)
    end

    test "refuses an id that is not letters, digits, _ and -" do
      book = update_chapter(update_prayer(book(), "id", "../sub tuum"), "id", "our lady")

      assert book_errors(book) =~ ~s(the prayer id "../sub tuum" may hold only)
      assert book_errors(book) =~ ~s(the chapter id "our lady" may hold only)
    end
  end

  describe "the Consecration's check" do
    test "the file as it is passes" do
      assert Check.consecration_errors(Library.sections(:consecration)) == []
    end

    test "refuses phases with a gap between them" do
      [first, second] = consecration()["phases"]
      gapped = %{consecration() | "phases" => [first, %{second | "first_day" => 4}]}

      assert consecration_errors(gapped) =~ "the phases run from day 1 without a gap"
    end

    test "refuses a phase with no prayers, or ending before it begins" do
      assert consecration_errors(update_phase(consecration(), "prayer_ids", [])) =~
               "the phase preparatory: it needs prayers"

      assert consecration_errors(update_phase(consecration(), "last_day", 0)) =~
               "the phase preparatory: its first_day and last_day are whole numbers, the first no later than the last"
    end

    test "refuses a phase or a day that is not a map, without crashing the check" do
      [_first | rest] = consecration()["phases"]

      assert consecration_errors(%{consecration() | "phases" => ["preparatory" | rest]}) =~
               ~s(a phase needs an id: "preparatory")

      assert consecration_errors(%{consecration() | "days" => [1]}) =~
               "a day needs a number: 1"
    end

    test "refuses a last day that is not a whole number, without crashing the check" do
      [first, last] = consecration()["phases"]
      document = %{consecration() | "phases" => [first, %{last | "last_day" => "3"}]}

      assert consecration_errors(document) =~ "the phase week_one: its first_day and last_day"
      assert consecration_errors(document) =~ "the days are numbered 1 to the last phase's"
    end

    test "refuses repeated ids, and ids that are not letters, digits, _ and -" do
      document = consecration()

      repeated = %{
        document
        | "prayers" => document["prayers"] ++ document["prayers"],
          "feasts" => document["feasts"] ++ document["feasts"]
      }

      assert consecration_errors(repeated) =~ ~s(the prayer id "veni_creator" is repeated)
      assert consecration_errors(repeated) =~ ~s(the feast id "lourdes" is repeated)

      [first, second] = document["phases"]
      twice = %{document | "phases" => [first, %{second | "id" => "preparatory"}]}

      assert consecration_errors(twice) =~ ~s(the phase id "preparatory" is repeated)

      assert consecration_errors(update_phase(document, "id", "week one")) =~
               ~s(the phase id "week one" may hold only)
    end

    test "refuses missing text, and a field that is neither text nor null" do
      assert consecration_errors(update_day(consecration(), "journal_prompt", "")) =~
               "the day 1: journal_prompt is required text"

      [reading] = hd(consecration()["days"])["readings"]

      assert consecration_errors(
               update_day(consecration(), "readings", [%{reading | "source" => 3}])
             ) =~ "the day 1: source is text or null"

      [prayer | rest] = consecration()["prayers"]
      document = %{consecration() | "prayers" => [%{prayer | "english" => nil} | rest]}

      assert consecration_errors(document) =~ "the prayer veni_creator: english is required text"
    end

    test "refuses a day missing, or outside its phase" do
      [one, _two, three] = consecration()["days"]

      assert consecration_errors(%{consecration() | "days" => [one, three]}) =~
               "the days are numbered 1 to the last phase's last day"

      assert consecration_errors(update_day(consecration(), "phase_id", "week_one")) =~
               "the day 1: it falls outside its phase week_one"

      assert consecration_errors(update_day(consecration(), "phase_id", "nowhere")) =~
               ~s(the day 1: names the phase "nowhere")
    end

    test "refuses a day with no readings, or readings out of order" do
      [reading] = hd(consecration()["days"])["readings"]

      assert consecration_errors(update_day(consecration(), "readings", [])) =~
               "the day 1: it needs readings"

      assert consecration_errors(
               update_day(consecration(), "readings", [%{reading | "order" => 2}])
             ) =~ "its readings are in order, numbered from 1"
    end

    test "refuses a phase naming a missing prayer, and a prayer no phase names" do
      [first | rest] = consecration()["phases"]
      document = %{consecration() | "phases" => [%{first | "prayer_ids" => ["nowhere"]} | rest]}

      assert consecration_errors(document) =~
               ~s(the phase preparatory: names the prayer "nowhere")

      assert consecration_errors(document) =~ "the prayer veni_creator is in no phase"
    end

    test "refuses Latin that does not pair with the English line for line" do
      [prayer | rest] = consecration()["prayers"]
      document = %{consecration() | "prayers" => [%{prayer | "latin" => "Una"} | rest]}

      assert consecration_errors(document) =~ "veni_creator has 2 English lines and 1 Latin"
    end

    test "refuses a feast on a date that does not exist, or with no date" do
      [feast] = consecration()["feasts"]

      assert consecration_errors(%{consecration() | "feasts" => [%{feast | "day" => 30}]}) =~
               "the feast lourdes: 2/30 is not a date"

      assert consecration_errors(%{consecration() | "feasts" => [Map.delete(feast, "month")]}) =~
               "the feast lourdes: it needs a month and a day"
    end

    test "refuses feasts out of calendar order" do
      [lourdes] = consecration()["feasts"]
      guadalupe = %{lourdes | "id" => "guadalupe", "month" => 12, "day" => 12}

      assert consecration_errors(%{consecration() | "feasts" => [guadalupe, lourdes]}) =~
               "the feasts are in calendar order"

      assert Check.consecration_errors(%{consecration() | "feasts" => [lourdes, guadalupe]}) ==
               []
    end

    test "refuses text a type would change, naming its section" do
      assert Library.cast_errors(:consecration, consecration()) == []

      assert [message] =
               Library.cast_errors(:consecration, update_day(consecration(), "title", "Day "))

      assert message =~ "days would not be served as written"
      assert message =~ ~r/: 1\z/
    end
  end

  describe "True Devotion's check" do
    test "the file as it is passes" do
      assert Check.true_devotion_errors(Library.sections(:true_devotion)) == []
    end

    test "the chapter ids are the ones the iOS app keeps a reader's progress by" do
      assert Enum.map(Library.sections(:true_devotion)["chapters"], & &1["id"]) ==
               ~w(introduction necessity discernment false-devotions characters preliminary
                  consists motives figure effects practices communion formula)
    end

    test "refuses parts out of order, and a chapter in no part there is" do
      [first, second] = true_devotion()["parts"]

      assert true_devotion_errors(%{true_devotion() | "parts" => [second, first]}) =~
               "the parts are numbered 1, 2 and on, in order"

      assert true_devotion_errors(update_td_chapter(true_devotion(), "part", 3)) =~
               "chapter introduction: its part is not one of the parts"
    end

    test "refuses paragraphs out of order, of no kind, or with no text" do
      [first, second | _] = hd(true_devotion()["chapters"])["paragraphs"]

      assert true_devotion_errors(
               update_td_chapter(true_devotion(), "paragraphs", [second, first])
             ) =~
               "chapter introduction: its paragraphs are numbered 0, 1, 2 and on, in order"

      assert true_devotion_errors(
               update_td_chapter(true_devotion(), "paragraphs", [%{first | "kind" => "verse"}])
             ) =~ "chapter introduction: paragraph 0 is neither text nor a subheading"

      assert true_devotion_errors(
               update_td_chapter(true_devotion(), "paragraphs", [%{first | "text" => " "}])
             ) =~ "chapter introduction: paragraph 0: text is required text"

      assert true_devotion_errors(update_td_chapter(true_devotion(), "paragraphs", [])) =~
               "chapter introduction: it has no paragraphs"
    end

    test "refuses a repeated chapter id, and one that is not letters, digits, _ and -" do
      [first | rest] = true_devotion()["chapters"]

      assert true_devotion_errors(%{true_devotion() | "chapters" => [first, first | rest]}) =~
               ~s(the chapter id "introduction" is repeated)

      assert true_devotion_errors(update_td_chapter(true_devotion(), "id", "the intro")) =~
               ~s(the chapter id "the intro" may hold only letters, digits, _ and -)
    end

    test "refuses a missing about, and about without its text" do
      assert true_devotion_errors(Map.delete(true_devotion(), "about")) =~
               "the document needs an about"

      about = Map.delete(true_devotion()["about"], "translator")

      assert true_devotion_errors(%{true_devotion() | "about" => about}) =~
               "translator is required text"
    end

    test "refuses text a type would change, naming its section" do
      assert Library.cast_errors(:true_devotion, true_devotion()) == []

      assert [message] =
               Library.cast_errors(
                 :true_devotion,
                 update_td_chapter(true_devotion(), "title", "Introduction ")
               )

      assert message =~ "chapters would not be served as written"
      assert message =~ "introduction"
    end
  end

  describe "the Chant Library's check" do
    test "the file as it is passes" do
      assert Check.chant_library_errors(Library.sections(:chant_library), Library.prayer_ids()) ==
               []
    end

    test "refuses a chant in no group's parts, and a part naming no chant" do
      library = update_chant(library(), "id", "renamed")

      assert errors(library) =~ "the chant renamed is in no group's parts"
      assert errors(library) =~ ~s(names the chant "salve_regina_simple")
    end

    test "refuses a prayer id the book does not hold, when given the book's" do
      library = update_chant(library(), "prayer_ids", ["nowhere"])

      assert Check.chant_library_errors(library) == []
      assert errors(library, ["sub_tuum"]) =~ ~s(names the prayer "nowhere")
    end

    test "refuses lines out of order, past the recording, or on a page that is not there" do
      [one, two] = library()["chants"] |> hd() |> Map.fetch!("lines")

      assert errors(update_chant(library(), "lines", [two, one])) =~
               "its lines are in the order they are sung"

      assert errors(update_chant(library(), "lines", [one, %{two | "end" => 999}])) =~
               "within the recording"

      assert errors(update_chant(library(), "lines", [one, %{two | "part" => 1}])) =~
               "a line's part is one of its score pages"
    end

    test "refuses a file with no URL, or one not named by its checksum" do
      chant = hd(library()["chants"])

      assert errors(update_chant(library(), "audio", %{chant["audio"] | "url" => nil})) =~
               "its audio needs a url"

      wrong = String.replace(chant["audio"]["url"], "3d83eac83eca", "000000000000")

      assert errors(update_chant(library(), "audio", %{chant["audio"] | "url" => wrong})) =~
               "does not end in chants/audio/salve_regina_simple-<first 12 of its sha256>.m4a"

      [page] = chant["score"]

      assert errors(update_chant(library(), "score", [%{page | "sha256" => "ABC"}])) =~
               "sha256 is 64 lowercase hex"
    end

    test "refuses a chant whose group does not exist" do
      assert errors(update_chant(library(), "group_id", "nowhere")) =~
               ~s(names the group "nowhere")
    end

    test "refuses repeated group and chant ids" do
      library = library()

      library = %{
        library
        | "groups" => library["groups"] ++ library["groups"],
          "chants" => library["chants"] ++ library["chants"]
      }

      assert errors(library) =~ ~s(the group id "ourLady" is repeated)
      assert errors(library) =~ ~s(the chant id "salve_regina_simple" is repeated)
    end

    test "refuses a duration that is not above zero" do
      assert errors(update_chant(library(), "duration", 0)) =~
               "its duration is a number of seconds above zero"

      assert errors(update_chant(library(), "duration", "185")) =~ "its duration"
    end

    test "refuses a URL that is not https" do
      chant = hd(library()["chants"])
      url = String.replace(chant["audio"]["url"], "https://", "http://")

      assert errors(update_chant(library(), "audio", %{chant["audio"] | "url" => url})) =~
               "its audio's url is https"
    end

    test "refuses a score part with no caption or an aspect ratio not above zero" do
      [page] = hd(library()["chants"])["score"]

      assert errors(update_chant(library(), "score", [Map.delete(page, "caption")])) =~
               "a score part needs a file, a caption and an aspect ratio above zero"

      assert errors(update_chant(library(), "score", [%{page | "aspect_ratio" => 0}])) =~
               "a score part needs"
    end

    test "refuses a chant id or score file that is not letters, digits, _ and -" do
      [page] = hd(library()["chants"])["score"]

      assert errors(update_chant(library(), "score", [%{page | "file" => "../chant"}])) =~
               ~s(the score file "../chant" may hold only)

      assert errors(update_chant(library(), "id", "salve regina")) =~
               ~s(the chant id "salve regina" may hold only)
    end

    test "refuses chant files on two bases, or off the one it is given" do
      chant = hd(library()["chants"])
      elsewhere = String.replace(chant["audio"]["url"], "lumenviae-images", "elsewhere")
      library = update_chant(library(), "audio", %{chant["audio"] | "url" => elsewhere})

      assert errors(library) =~ "every chant file is on one base"

      assert Check.chant_library_errors(library(), nil, "https://cdn.example.org")
             |> Enum.join() =~
               "every chant file's url starts with https://cdn.example.org/chants/"

      assert Check.chant_library_errors(library(), nil, @base) == []
    end
  end

  defp book_errors(book), do: book |> Check.prayer_book_errors() |> Enum.join("\n")

  defp true_devotion_errors(document),
    do: document |> Check.true_devotion_errors() |> Enum.join("\n")

  defp true_devotion, do: Library.sections(:true_devotion)

  defp update_td_chapter(document, key, value) do
    [first | rest] = document["chapters"]
    %{document | "chapters" => [Map.put(first, key, value) | rest]}
  end

  defp consecration_errors(document),
    do: document |> Check.consecration_errors() |> Enum.join("\n")

  # Two phases of three days, the second's prayer said in English alone.
  defp consecration do
    %{
      "phases" => [
        phase("preparatory", 1, 2, ["veni_creator"]),
        phase("week_one", 3, 3, ["act_of_consecration"])
      ],
      "days" => [day(1, "preparatory"), day(2, "preparatory"), day(3, "week_one")],
      "prayers" => [
        %{
          "id" => "veni_creator",
          "title" => "Come, Creator Spirit",
          "latin_title" => "Veni Creator Spiritus",
          "english" => "Come, Holy Ghost,\nCreator blest.",
          "latin" => "Veni, Creator Spiritus,\nmentes tuorum visita."
        },
        %{
          "id" => "act_of_consecration",
          "title" => "Act of Consecration",
          "latin_title" => nil,
          "english" => "O Eternal and Incarnate Wisdom!",
          "latin" => nil
        }
      ],
      "feasts" => [
        %{
          "id" => "lourdes",
          "name" => "Our Lady of Lourdes",
          "month" => 2,
          "day" => 11,
          "description" => "Apparition of the Immaculate Virgin Mary at Lourdes"
        }
      ]
    }
  end

  defp phase(id, first_day, last_day, prayer_ids) do
    %{
      "id" => id,
      "name" => id,
      "subtitle" => "Letting Go of the World",
      "first_day" => first_day,
      "last_day" => last_day,
      "painting" => "luminous_baptism",
      "prayer_ids" => prayer_ids
    }
  end

  defp day(number, phase_id) do
    %{
      "number" => number,
      "phase_id" => phase_id,
      "title" => "The Spirit of the World",
      "readings" => [
        %{
          "order" => 1,
          "title" => "Matthew 5:1-19",
          "text" => "And seeing the multitudes, he went up into a mountain.",
          "source" => "Douay-Rheims Bible"
        }
      ],
      "journal_prompt" => "What must you release?"
    }
  end

  defp update_phase(document, key, value) do
    [first | rest] = document["phases"]
    %{document | "phases" => [Map.put(first, key, value) | rest]}
  end

  defp update_day(document, key, value) do
    [first | rest] = document["days"]
    %{document | "days" => [Map.put(first, key, value) | rest]}
  end

  defp errors(library, prayer_ids \\ nil),
    do: library |> Check.chant_library_errors(prayer_ids) |> Enum.join("\n")

  defp book do
    %{
      "prayers" => [
        prayer(
          "sub_tuum",
          "We fly to thy patronage,\nO holy Mother of God.",
          "Sub tuum\npraesidium."
        ),
        prayer("memorare", "Remember, O most gracious Virgin Mary.", nil)
      ],
      "chapters" => [
        %{
          "id" => "our_lady",
          "numeral" => "I",
          "title" => "Our Lady",
          "latin_title" => "Beata Maria Virgo",
          "note" => nil,
          "topic" => nil,
          "search_words" => [],
          "prayer_ids" => ["sub_tuum", "memorare"],
          "sections" => [%{"title" => "To Our Lady", "prayer_ids" => ["sub_tuum", "memorare"]}]
        }
      ]
    }
  end

  defp prayer(id, english, latin) do
    %{
      "id" => id,
      "title" => id,
      "latin_title" => nil,
      "origin" => nil,
      "note" => nil,
      "english" => english,
      "latin" => latin,
      "list_title" => nil,
      "english_name" => nil,
      "search_words" => []
    }
  end

  defp update_prayer(book, key, value) do
    [first | rest] = book["prayers"]
    %{book | "prayers" => [Map.put(first, key, value) | rest]}
  end

  defp update_chapter(book, key, value) do
    [first | rest] = book["chapters"]
    %{book | "chapters" => [Map.put(first, key, value) | rest]}
  end

  defp library do
    %{
      "groups" => [
        %{
          "id" => "ourLady",
          "title" => "Our Lady",
          "note" => nil,
          "parts" => [%{"title" => nil, "note" => nil, "chant_ids" => ["salve_regina_simple"]}]
        }
      ],
      "chants" => [
        %{
          "id" => "salve_regina_simple",
          "group_id" => "ourLady",
          "latin_title" => "Salve Regina",
          "english_title" => "Hail, Holy Queen",
          "setting" => nil,
          "detail" => "The evening song to Mary",
          "prayer_ids" => ["sub_tuum"],
          "duration" => 185,
          "source_url" => "https://www.verbumgloriae.es/project/salve-regina-simple/",
          "audio" => %{
            "url" => "#{@base}/chants/audio/salve_regina_simple-3d83eac83eca.m4a",
            "bytes" => 760_764,
            "sha256" => @sha
          },
          "score" => [
            %{
              "file" => "chant-salve-regina-simple",
              "caption" => "Salve Regina",
              "aspect_ratio" => 1.0797,
              "url" => "#{@base}/chants/scores/chant-salve-regina-simple-8748a1058c7c.lvscore",
              "bytes" => 62_390,
              "sha256" => @score_sha
            }
          ],
          "lines" => [
            line("Salve, Regina", 0.41, 11.83, 0),
            line("Vita, dulcedo", 11.83, 22.58, nil)
          ]
        }
      ]
    }
  end

  defp line(latin, start, finish, part),
    do: %{"latin" => latin, "english" => latin, "start" => start, "end" => finish, "part" => part}

  defp update_chant(library, key, value) do
    [first | rest] = library["chants"]
    %{library | "chants" => [Map.put(first, key, value) | rest]}
  end
end
