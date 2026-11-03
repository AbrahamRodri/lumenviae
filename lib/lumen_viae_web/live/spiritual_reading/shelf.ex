defmodule LumenViaeWeb.Live.SpiritualReading.Shelf do
  @moduledoc """
  The Spiritual Reading shelf as the website's pages read it, over
  `LumenViae.Rosary.get_spiritual_reading!/1` (the catalogue) and
  `LumenViae.Rosary.read_spiritual_book!/2` (a book's text, fetched from
  Project Gutenberg by the server and cut as the apps cut it). How the
  pages arrange a book is the iOS app's (`LibraryBookView`,
  `LibraryContentsView`'s `LibraryPartRun` and `LibraryBookPlace`,
  `LibraryChapterReaderView`): the runs of chapters under their parts, the
  numeral each row leads with, the short place on Continue ("III.V"), a
  row's title, a chapter's kicker, the versal and the footnote markers.
  Presentation only.

  A chapter's address counts from 1 (`/spiritual-reading/imitation-of-christ/1`),
  where the book counts its chapters from 0.
  """

  alias LumenViae.Rosary

  @opening_quotes ["“", "‘", "\"", "'"]

  @doc "The shelf's books, in the catalogue's order."
  def books(actor), do: Rosary.get_spiritual_reading!(actor: actor, load: [:books]).books

  @doc "The catalogue's book with this id, or nil."
  def book(actor, id), do: Enum.find(books(actor), &(&1.id == id))

  @doc """
  The book's text, as `read_spiritual_book!/2` answers it: its `status`
  (`:ok`, `:not_found`, `:unreachable`, `:unreadable`, or `:cold` when
  `cached_only:` is set and the server has not fetched the book yet) and,
  when `:ok`, its `contents` and, with `chapter:`, that chapter.
  """
  def read(actor, book_id, opts \\ []) do
    params =
      opts
      |> Keyword.take([:chapter, :cached_only])
      |> Map.new()

    Rosary.read_spiritual_book!(book_id, params, actor: actor)
  end

  @doc "The shelf's path."
  def path, do: "/spiritual-reading"

  @doc "A book's path."
  def book_path(id), do: "/spiritual-reading/#{id}"

  @doc "A chapter's path, by its index in the book from 0."
  def chapter_path(book_id, index), do: "/spiritual-reading/#{book_id}/#{index + 1}"

  @doc """
  The chapter index from 0 a chapter's address names (counting from 1),
  or `:error` for anything that is not a whole number from 1.
  """
  def parse_chapter(param) do
    case Integer.parse(to_string(param)) do
      {n, ""} when n >= 1 -> {:ok, n - 1}
      _other -> :error
    end
  end

  @doc """
  The book's cloth, a class naming its binding colour (the app's
  `bindingColor`, the `--color-cloth-*` tokens).
  """
  def cloth(id), do: "sr-cloth--#{id}"

  @doc "\"Thomas à Kempis · translated by William Benham\", as the shelf names a book."
  def author_line(%{translator: nil} = book), do: book.author
  def author_line(book), do: "#{book.author} · translated by #{book.translator}"

  @doc """
  The book page's credit, as the app's: "Text: Project Gutenberg eBook
  #1653. Public domain." The app adds the recording's credit; the site
  plays no recording yet.
  """
  def credit(book), do: "Text: Project Gutenberg eBook ##{book.gutenberg_id}. Public domain."

  @doc "Project Gutenberg's own page for the book, which the credit links to."
  def gutenberg_url(book), do: "https://www.gutenberg.org/ebooks/#{book.gutenberg_id}"

  # -- The contents ---------------------------------------------------------

  @doc """
  The chapters as runs under their parts (`LibraryPartRun.runs`): one run
  per stretch of chapters sharing a part, a book with no parts one run
  with no title. Each run carries its `number` as the book counts its
  parts (1 for the first named one; nil for front matter, which is no
  part).
  """
  def runs(chapters) do
    runs =
      chapters
      |> Enum.chunk_by(& &1.part)
      |> Enum.map(fn [first | _rest] = run -> %{title: first.part, chapters: run} end)

    {runs, _count} =
      Enum.map_reduce(runs, 0, fn
        %{title: nil} = run, count -> {Map.put(run, :number, nil), count}
        run, count -> {Map.put(run, :number, count + 1), count + 1}
      end)

    runs
  end

  @doc "Whether the book is printed in parts, so its page pins and indexes them."
  def parts?(runs), do: Enum.count(runs, & &1.title) > 1

  @doc "The parts a book prints by name, front matter left out."
  def titled(runs), do: Enum.filter(runs, & &1.title)

  @doc """
  The numeral a heading ends on ("V" of "Chapter V"), or nil for a
  heading with none ("Prologue"), read as strictly as the app reads one.
  """
  def numeral(heading) do
    words = String.split(heading, " ")

    with [_first, _second | _rest] <- words,
         last = List.last(words),
         true <- arabic?(last) or roman_value(last) != nil do
      last
    else
      _no_numeral -> nil
    end
  end

  defp arabic?(word), do: match?({_n, ""}, Integer.parse(word))

  @doc """
  The place on Continue (`LibraryBookPlace.shortName`): "III.V" in a book
  of parts, the heading itself ("Chapter V", "Prologue") in a book
  without them, in front matter, or where the heading carries no numeral;
  the part's numeral alone for a chapter whose heading is its part's name.
  """
  def short_name(chapter, runs) do
    run = Enum.find(runs, fn run -> Enum.any?(run.chapters, &(&1.id == chapter.id)) end)

    cond do
      not parts?(runs) or run == nil or run.number == nil ->
        chapter.heading

      tail = numeral(chapter.heading) ->
        "#{roman(run.number)}.#{tail}"

      chapter.heading == run.title ->
        roman(run.number)

      true ->
        chapter.heading
    end
  end

  @doc """
  "Continue reading, The Third Book, Chapter V, Of the wonderful power of
  the Divine Love": the act said in full, where "III.V" names no part to
  the ear.
  """
  def spoken(chapter) do
    [
      chapter.part != chapter.heading && chapter.part,
      chapter.heading,
      distinct_title?(chapter) && chapter.title
    ]
    |> Enum.filter(& &1)
    |> Enum.join(", ")
  end

  @doc "What the contents call a chapter: its title, or its heading where it prints none."
  def display_title(chapter), do: chapter.title || chapter.heading

  @doc "Whether the edition prints a title that says something the heading does not."
  def distinct_title?(chapter), do: chapter.title != nil and chapter.title != chapter.heading

  @doc """
  A row's one line of title: the chapter's own where its heading is only a
  number, "Prologue · The Parentage…" where the heading is a word, but
  not where the heading is the part's own name (pinned above it).
  """
  def row_title(chapter) do
    if distinct_title?(chapter) and numeral(chapter.heading) == nil and
         chapter.heading != chapter.part,
       do: "#{chapter.heading} · #{display_title(chapter)}",
       else: display_title(chapter)
  end

  @doc "Whether any chapter's heading carries a numeral, so the rows keep a column for them."
  def numbers_chapters?(chapters), do: Enum.any?(chapters, &numeral(&1.heading))

  @doc """
  The words over a chapter's title: "The First Book · Chapter II" under a
  part, the heading where the title says something else, and the book's
  own name where the heading is already the title.
  """
  def kicker(book, chapter) do
    cond do
      chapter.part -> "#{chapter.part} · #{chapter.heading}"
      distinct_title?(chapter) -> chapter.heading
      true -> book.title
    end
  end

  # -- A chapter's text ------------------------------------------------------

  @doc """
  A chapter's paragraphs as the page draws them, each a list of pieces:
  `{:text, words}`, or `{:note, marker, number}` for a footnote marker the
  edition prints (`note_pattern`). Not every match is a marker: one that
  follows a digit is the other numbering of a psalm ("Ps. 88[89]:1"), as
  the app reads it. The first paragraph carries the app's versal when it
  is at least 80 characters long and does not open on a quotation mark.
  """
  def paragraphs(chapter, note_pattern) do
    regex = compile(note_pattern)

    chapter.paragraphs
    |> Enum.with_index(1)
    |> Enum.map(fn {text, number} ->
      %{
        number: number,
        versal?: number == 1 and versal?(text),
        pieces: pieces(text, regex)
      }
    end)
  end

  @doc """
  The chapter's footnotes for the apparatus at its foot, each with the
  number its marker carries and the `anchor` a marker in the prose links
  to (`note-3`; nil for a note with no number, or one whose number an
  earlier note already took).
  """
  def notes(chapter) do
    {notes, _taken} =
      Enum.map_reduce(chapter.notes, MapSet.new(), fn note, taken ->
        number =
          case Regex.run(~r/^\D{0,2}(\d+)/, note) do
            [_all, digits] -> String.to_integer(digits)
            nil -> nil
          end

        anchor = if number && number not in taken, do: "note-#{number}"
        {%{number: number, text: note, anchor: anchor}, MapSet.put(taken, number)}
      end)

    notes
  end

  defp versal?(text), do: String.length(text) >= 80 and String.first(text) not in @opening_quotes

  defp pieces(text, nil), do: [{:text, text}]

  defp pieces(text, regex) do
    markers =
      for [{start, length}] <- Regex.scan(regex, text, return: :index),
          start == 0 or not digit_before?(text, start),
          digits = text |> binary_part(start, length) |> String.replace(~r/\D/, ""),
          digits != "",
          do: {start, length, String.to_integer(digits)}

    {pieces, cursor} =
      Enum.reduce(markers, {[], 0}, fn {start, length, number}, {pieces, cursor} ->
        before = binary_part(text, cursor, start - cursor)
        marker = binary_part(text, start, length)
        pieces = if before == "", do: pieces, else: [{:text, before} | pieces]
        {[{:note, marker, number} | pieces], start + length}
      end)

    tail = binary_part(text, cursor, byte_size(text) - cursor)
    pieces = if tail == "", do: pieces, else: [{:text, tail} | pieces]
    Enum.reverse(pieces)
  end

  defp digit_before?(text, start), do: binary_part(text, start - 1, 1) =~ ~r/\d/

  @doc "A chapter's description for search and link previews: its opening words."
  def description(book, chapter) do
    opening = chapter.paragraphs |> List.first("") |> String.slice(0, 200)
    "#{display_title(chapter)}, from #{book.title} by #{book.author}: #{opening}"
  end

  defp compile(nil), do: nil

  defp compile(pattern) do
    case Regex.compile(pattern, "u") do
      {:ok, regex} -> regex
      {:error, _reason} -> nil
    end
  end

  # -- Numerals ---------------------------------------------------------------

  @doc "A number as it would be printed in Roman numerals: 14 is \"XIV\"."
  def roman(number) do
    [
      {100, "C"},
      {90, "XC"},
      {50, "L"},
      {40, "XL"},
      {10, "X"},
      {9, "IX"},
      {5, "V"},
      {4, "IV"},
      {1, "I"}
    ]
    |> Enum.reduce({number, ""}, fn {value, letters}, {left, acc} ->
      {rem(left, value), acc <> String.duplicate(letters, div(left, value))}
    end)
    |> elem(1)
  end

  @doc """
  A Roman numeral's value, or nil (`LibraryNumerals.roman`): uppercase,
  written the canonical way, and no more than 200, so an all-caps word
  spelled in a numeral's letters ("DID", "CIVIL", "MIX") is never one.
  """
  def roman_value(token) do
    cleaned = String.trim(token, ".") |> String.trim(",") |> String.trim(":") |> String.trim(";")
    values = %{"I" => 1, "V" => 5, "X" => 10, "L" => 50, "C" => 100, "D" => 500, "M" => 1000}
    letters = String.graphemes(cleaned)

    with true <- cleaned != "" and cleaned == String.upcase(cleaned),
         true <- Enum.all?(letters, &Map.has_key?(values, &1)),
         total = subtractive(Enum.map(letters, &values[&1])),
         true <- total in 1..200,
         true <- roman(total) == cleaned do
      total
    else
      _not_a_numeral -> nil
    end
  end

  defp subtractive(values) do
    {total, _previous} =
      values
      |> Enum.reverse()
      |> Enum.reduce({0, 0}, fn value, {total, previous} ->
        if value < previous, do: {total - value, previous}, else: {total + value, value}
      end)

    total
  end
end
