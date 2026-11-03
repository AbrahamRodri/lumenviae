defmodule LumenViae.Rosary.SpiritualReadingParserTest do
  @moduledoc """
  The Gutenberg cutter, on the cases the iOS app's `LibraryBookParserTests`
  and Android's `LibraryBookParserTest` pin, and on the same real editions
  (excerpts in `test/support/fixtures/gutenberg`, as Gutenberg serves
  them), so the website cuts every book into the apps' chapters.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.SpiritualReading.Parser
  alias LumenViae.Rosary.SpiritualReading.Text

  @prose """
         And so it was that the soul, having been drawn by grace out of the
         noise of the world, came at last to rest in the _quiet_ of God, where
         nothing is wanting and nothing is feared, for He who made it holds it
         in the hollow of His hand and does not let it go.
         """
         |> String.trim()

  @edition """
           The Project Gutenberg eBook of A Test Book
           Licence words before the book.
           *** START OF THE PROJECT GUTENBERG EBOOK A TEST BOOK ***

           CONTENTS

           CHAPTER I The Dawn
           CHAPTER II The Second Title
           THE END

           CHAPTER I THE DAWN

           #{@prose}

           [1] Ps. 1:1. [2] Luke 2:19.

           CHAPTER II

           The Second Title.

           #{@prose}

           ______

           FINIS

           #{@prose}

           THE END

           AN APPENDIX THAT IS NOT THE BOOK

           #{@prose}
           *** END OF THE PROJECT GUTENBERG EBOOK A TEST BOOK ***
           Eighteen kilobytes of licence.
           """
           |> String.trim()

  defp rules(overrides) do
    Map.merge(
      %{
        chapter_pattern: "^CHAPTER [IVXLC]+",
        part_pattern: nil,
        start_pattern: nil,
        stop_pattern: "^THE END$",
        note_pattern: "\\[\\d+\\]",
        drop_pattern: "^FINIS$",
        title_runs_to_blank_gap: false,
        minimum_chapter_length: 200,
        maximum_title_length: 140
      },
      Map.new(overrides)
    )
  end

  defp info(overrides \\ [], titles \\ nil) do
    %{
      id: "test-book",
      gutenberg_id: 1,
      parsing: rules(overrides),
      chapter_titles: titles,
      heading_overrides: []
    }
  end

  defp parse(info \\ info(), text \\ @edition), do: Parser.parse(text, info)

  defp catalogue(id),
    do: Enum.find(Library.served(:spiritual_reading, "books"), &(&1.id == id))

  defp real(file, id) do
    "test/support/fixtures/gutenberg/#{file}" |> File.read!() |> Parser.parse(catalogue(id))
  end

  test "the contents page is no chapter, and THE END in it ends nothing" do
    book = parse()
    assert Enum.map(book.chapters, & &1.id) == [0, 1]
    assert book.book_id == "test-book"
  end

  test "headings are split and titles lifted" do
    [first, second] = parse().chapters
    assert {first.heading, first.title} == {"Chapter I", "The Dawn"}
    assert {second.heading, second.title} == {"Chapter II", "The Second Title"}
    refute Enum.any?(second.paragraphs, &String.starts_with?(&1, "The Second Title"))
  end

  test "hard-wrapped lines join and emphasis is unwrapped" do
    [paragraph | _rest] = hd(parse().chapters).paragraphs

    assert paragraph =~
             ~r/^And so it was that the soul, having been drawn by grace out of the noise/

    assert paragraph =~ "in the quiet of God"
    refute paragraph =~ "_"
    refute paragraph =~ "\n"
  end

  test "footnotes are lifted and split, only with a note pattern" do
    first = hd(parse().chapters)
    assert first.notes == ["[1] Ps. 1:1.", "[2] Luke 2:19."]
    assert length(first.paragraphs) == 1

    kept = hd(parse(info(note_pattern: nil)).chapters)
    assert kept.notes == []
    assert "[1] Ps. 1:1. [2] Luke 2:19." in kept.paragraphs
  end

  test "printer's marks, rules, the stop line and the licence fall away" do
    second = Enum.at(parse().chapters, 1)
    refute "FINIS" in second.paragraphs
    refute Enum.any?(second.paragraphs, &(&1 =~ "______"))
    assert length(second.paragraphs) == 2

    all = parse().chapters |> Enum.flat_map(& &1.paragraphs) |> Enum.join(" ")
    refute all =~ "APPENDIX"
    refute all =~ "icence"

    run_on =
      info(stop_pattern: nil) |> parse() |> Map.get(:chapters) |> Enum.flat_map(& &1.paragraphs)

    assert Enum.join(run_on, " ") =~ "AN APPENDIX"
    refute Enum.join(run_on, " ") =~ "Eighteen kilobytes"
  end

  test "CRLF cuts the same way" do
    assert parse(info(), String.replace(@edition, "\n", "\r\n")) == parse()
  end

  test "a curated title stands only where none is printed" do
    titled = info([], ["Curated One", "Curated Two"])
    text = String.replace(@edition, "The Second Title.\n", "")
    [first, second] = parse(titled, text).chapters
    assert first.title == "The Dawn"
    assert second.title == "Curated Two"
  end

  test "a heading override replaces the printed heading by index" do
    info = %{info() | heading_overrides: [%{chapter: 1, heading: "Chapter LXI"}]}
    assert Enum.map(parse(info).chapters, & &1.heading) == ["Chapter I", "Chapter LXI"]
  end

  @forms_prose String.duplicate(
                 "The soul rests in God and wants for nothing, and fears nothing. ",
                 12
               )

  @forms """
  *** START OF THE PROJECT GUTENBERG EBOOK A TEST BOOK ***

  Book First.

  _CHAPTER I._

   God reveals Himself to us as Mysteriously, as Adorably, and with as
   much Reality in the most Ordinary Events as in the great Events of
   History and the Holy Scriptures.


  #{@forms_prose}

  DISCOURSE II.

  ON THE BIRTH OF MARY.

  #{@forms_prose}

  FIRST LETTER.

  _To the Same_

  #{@forms_prose}

  *** END OF THE PROJECT GUTENBERG EBOOK A TEST BOOK ***
  """

  defp forms_info(maximum \\ 140) do
    info(
      chapter_pattern: "^(_?CHAPTER [IVXLC]+\\._?|DISCOURSE [IVXLC]+\\.|FIRST LETTER\\.)$",
      part_pattern: "^Book (First|Second)\\.$",
      stop_pattern: nil,
      note_pattern: nil,
      drop_pattern: nil,
      minimum_chapter_length: 500,
      maximum_title_length: maximum
    )
  end

  test "underscores and closing stops are read out of headings and parts" do
    chapters = Parser.parse(@forms, forms_info()).chapters
    assert Enum.map(chapters, & &1.heading) == ["Chapter I", "Discourse II", "First Letter"]
    assert hd(chapters).part == "Book First"
    assert Enum.at(chapters, 1).title == "On the Birth of Mary"
    assert Enum.at(chapters, 2).title == "To the Same"
  end

  test "a long title is the body at 140 and the title when the rule allows" do
    short = hd(Parser.parse(@forms, forms_info()).chapters)
    assert short.title == nil
    assert hd(short.paragraphs) =~ ~r/^God reveals Himself/

    long = hd(Parser.parse(@forms, forms_info(220)).chapters)
    assert long.title =~ ~r/^God reveals Himself/
    assert hd(long.paragraphs) =~ ~r/^The soul rests/
  end

  test "a marker is cut only where it follows a space, in number order" do
    text =
      "*** START OF THE PROJECT GUTENBERG EBOOK X ***\n\nCHAPTER I\n\nThe Title\n\n" <>
        "#{@prose} #{@prose}\n\n[1] Ps. 88[89]:1. [2] Luke 2:19.\n"

    assert hd(parse(info(), text).chapters).notes == ["[1] Ps. 88[89]:1.", "[2] Luke 2:19."]
  end

  test "a title set over several blocks is joined where the rule allows" do
    text =
      "*** START OF THE PROJECT GUTENBERG EBOOK X ***\n\nCHAPTER I\n\nJesus Falls.\n\n" <>
        "The Daughters of Jerusalem.\n\n\n#{@prose} #{@prose}\n"

    joined = hd(parse(info(title_runs_to_blank_gap: true), text).chapters)
    assert joined.title == "Jesus Falls. The Daughters of Jerusalem"
    assert hd(parse(info(), text).chapters).title == "Jesus Falls"
  end

  describe "the real editions, cut by the catalogue's rules" do
    test "Brother Lawrence cuts whole" do
      book = real("pg13871.txt", "practice-of-the-presence-of-god")
      assert length(book.chapters) == 20
      assert hd(book.chapters).heading == "Preface"

      assert book.chapters |> Enum.map(& &1.part) |> Enum.reject(&is_nil/1) |> Enum.uniq() ==
               ["Conversations", "Letters"]

      assert Enum.at(book.chapters, 1).heading == "First Conversation"
      assert List.last(book.chapters).heading == "Fifteenth Letter"
    end

    test "the Imitation's Fourth Book opens with its own exhortation" do
      book = real("pg1653-excerpt.txt", "imitation-of-christ")
      [exhortation, first | _rest] = Enum.filter(book.chapters, &(&1.part == "The Fourth Book"))
      assert exhortation.heading == "The Fourth Book"
      assert Enum.any?(exhortation.paragraphs, &(&1 =~ "Come unto Me, all ye that labour"))
      assert first.heading == "Chapter I"

      # The contents page names every chapter and is none of them.
      opening = hd(book.chapters)
      assert opening.heading == "Chapter I"

      assert opening.title ==
               "Of the imitation of Christ, and of contempt of the world and all its vanities"

      assert opening.notes != []
    end

    test "the Story of a Soul starts at its Prologue, not its contents" do
      [prologue, first | _rest] = real("pg16772-excerpt.txt", "story-of-a-soul").chapters
      assert prologue.heading == "Prologue"
      assert prologue.title == "The Parentage & Birth of Marie Françoise Thérèse Martin"
      assert {first.heading, first.title} == {"Chapter I", "Earliest Memories"}
    end

    test "the Glories of Mary stop at its footnotes" do
      book = real("pg72411-excerpt.txt", "glories-of-mary")
      assert hd(book.chapters).heading == "Introduction"
      last = List.last(book.chapters)
      assert last.heading == "Various Prayers to Mary"
      refute Enum.any?(last.paragraphs, &String.starts_with?(&1, "FOOTNOTES"))
    end
  end

  test "the edition's fingerprint is the iOS app's" do
    # Eight hex digits that differ from book to book, and change when a
    # book's rules do (iOS's editionFingerprint, FNV-1a over the rules).
    assert Text.fingerprint(catalogue("imitation-of-christ")) =~ ~r/^[0-9a-f]{8}$/

    refute Text.fingerprint(catalogue("imitation-of-christ")) ==
             Text.fingerprint(catalogue("story-of-a-soul"))
  end

  test "each piece of a hyphenated word is capitalized, as iOS sets it" do
    assert Parser.title_cased("MARY IS THE PEACE-MAKER BETWEEN SINNERS AND GOD") ==
             "Mary Is the Peace-Maker Between Sinners and God"
  end
end
