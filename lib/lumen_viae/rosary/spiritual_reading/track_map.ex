defmodule LumenViae.Rosary.SpiritualReading.TrackMap do
  @moduledoc """
  Ties a book's LibriVox recording to the chapters cut from its text, so a
  chapter can be handed to the voice. A port, line for line, of the iOS
  app's `LibraryTrackMap` and `LibraryNumerals` (and Android's copy of
  them): the alignment is read from what the recording says its tracks are
  (their titles) against what the parser produced, and a chapter with no
  track simply has none. A book whose recording cannot be aligned (`none`)
  has an empty alignment.

  By the book's `track_mapping` in the catalogue:

    * `sequential`: chapter `i` is read by track `i + offset`, the chapters
      in `unread` taking no track and shifting the rest back by one, and
      tracks titled "... Part 1", "... Part 2" one reading;
    * `book_chapter_ranges`: a track's title names a part and a span of
      chapters ("Book 3 - Chapters 21-30"), matched on the chapter's part
      and its heading's number;
    * `book_spans`: a chapter is a whole book read over several tracks
      ("Book Ten, Chapters 21-30"), opening at the first track naming it.

  A chapter here is the parser's (`part`, `heading`); a track the
  recording's (`title`), in the feed's order.
  """

  defmodule Alignment do
    @moduledoc """
    Which track reads which chapter, both ways round (`LibraryTrackAlignment`).
    `chapter_to_track` is a list by chapter index (nil where no track reads
    it); `track_to_chapters` a map of track index to the `Range` of
    chapters it reads; `whole` the tracks that read exactly one whole
    chapter (one chapter, which no other track also reads), the only ones
    a page can follow along with.
    """
    defstruct chapter_to_track: [], track_to_chapters: %{}, whole: MapSet.new()

    @doc "An alignment from both maps, with the tracks that read one whole chapter worked out."
    def new(chapter_to_track, track_to_chapters) do
      single = for {track, first..last//_} <- track_to_chapters, first == last, do: {track, first}
      per_chapter = Enum.frequencies_by(single, &elem(&1, 1))

      whole =
        for {track, chapter} <- single, per_chapter[chapter] == 1, into: MapSet.new(), do: track

      %__MODULE__{
        chapter_to_track: chapter_to_track,
        track_to_chapters: track_to_chapters,
        whole: whole
      }
    end

    def empty, do: %__MODULE__{}

    @doc "Whether any chapter at all is tied to a track."
    def empty?(%__MODULE__{track_to_chapters: map}), do: map == %{}

    @doc "The track that reads this chapter, or nil."
    def track(%__MODULE__{chapter_to_track: list}, index) when index >= 0,
      do: Enum.at(list, index)

    def track(_alignment, _index), do: nil

    @doc "The chapters this track reads, as a range, or nil."
    def chapters(%__MODULE__{track_to_chapters: map}, track), do: Map.get(map, track)

    @doc "The chapter a track opens with, or nil."
    def first_chapter(alignment, track) do
      case chapters(alignment, track) do
        nil -> nil
        first.._last//_ -> first
      end
    end

    @doc "Whether this track reads one whole chapter, the only case the page can keep pace with."
    def reads_whole_chapter?(%__MODULE__{whole: whole}, track), do: MapSet.member?(whole, track)
  end

  @part ~r/[\s,\-–—]*\bp(?:ar)?t\.?\s*([0-9]+)\s*$/iu
  @span ~r/\bbook\s+([IVXLC]+|[0-9]+)\b.*?\b([0-9]+)\s*(?:[-–—]|to)\s*([0-9]+)\b/iu

  @doc """
  Aligns `chapters` (each with `:part` and `:heading`) against `tracks`
  (each with `:title`) by `mapping` (`%{kind:, offset:, unread:}`).
  """
  def align(chapters, tracks, mapping) do
    cond do
      chapters == [] or tracks == [] or mapping == nil ->
        Alignment.empty()

      true ->
        case mapping.kind do
          "sequential" ->
            sequential(chapters, tracks, mapping.offset || 0, MapSet.new(mapping.unread || []))

          "book_chapter_ranges" ->
            book_chapter_ranges(chapters, tracks)

          "book_spans" ->
            book_spans(chapters, tracks)

          _none ->
            Alignment.empty()
        end
    end
  end

  # -- Book spans -------------------------------------------------------------

  # One reading unit, several tracks: the unit's heading carries its number
  # ("Book X" is 10) and each track names the book it reads; the unit opens
  # at the first track of its book.
  defp book_spans(chapters, tracks) do
    book_of_track =
      for {track, index} <- Enum.with_index(tracks),
          is_binary(track.title),
          book = book_number(track.title),
          book != nil,
          do: {index, book}

    first_track =
      Enum.reduce(book_of_track, %{}, fn {index, book}, acc -> Map.put_new(acc, book, index) end)

    if first_track == %{} do
      Alignment.empty()
    else
      {chapter_to_track, chapter_of_book} =
        chapters
        |> Enum.with_index()
        |> Enum.map_reduce(%{}, fn {chapter, index}, chapter_of_book ->
          case number(chapter.heading) do
            nil -> {nil, chapter_of_book}
            book -> {first_track[book], Map.put(chapter_of_book, book, index)}
          end
        end)

      track_to_chapters =
        for {track, book} <- book_of_track,
            chapter = chapter_of_book[book],
            chapter != nil,
            into: %{},
            do: {track, chapter..chapter}

      Alignment.new(chapter_to_track, track_to_chapters)
    end
  end

  # -- Sequential -------------------------------------------------------------

  # Chapter i is read by track i + offset, a chapter the recording passes
  # over taking none and shifting the rest back by one; tracks are grouped
  # into readings first, so "... Part 2" belongs to its chapter too.
  defp sequential(chapters, tracks, offset, unread) do
    groups = grouped_by_continuation(tracks)

    {pairs, _passed_over} =
      chapters
      |> Enum.with_index()
      |> Enum.map_reduce(0, fn {_chapter, index}, passed_over ->
        if MapSet.member?(unread, index) do
          {{index, nil}, passed_over + 1}
        else
          position = index + offset - passed_over
          group = if position >= 0, do: Enum.at(groups, position)
          {{index, group}, passed_over}
        end
      end)

    chapter_to_track = Enum.map(pairs, fn {_index, group} -> group && hd(group) end)

    track_to_chapters =
      for {index, group} <- pairs,
          group != nil,
          track <- group,
          into: %{},
          do: {track, index..index}

    Alignment.new(chapter_to_track, track_to_chapters)
  end

  # Consecutive tracks that are parts of one reading, gathered: a trailing
  # "Part 2" over the same title as the track before it.
  defp grouped_by_continuation(tracks) do
    {groups, _previous} =
      tracks
      |> Enum.with_index()
      |> Enum.reduce({[], nil}, fn {track, index}, {groups, previous_base} ->
        title = track.title || ""
        base = base_title(title)
        part = continuation_part(title)

        if part != nil and part > 1 and previous_base != nil and base == previous_base and
             groups != [] do
          [last | rest] = groups
          {[last ++ [index] | rest], previous_base}
        else
          {[[index] | groups], base}
        end
      end)

    Enum.reverse(groups)
  end

  defp continuation_part(title) do
    case Regex.run(@part, title) do
      [_all, digits] -> String.to_integer(digits)
      nil -> nil
    end
  end

  # The title with any trailing part number taken off, folded for
  # comparison (these titles are hand-typed).
  defp base_title(title) do
    @part
    |> Regex.replace(title, "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.downcase()
  end

  # -- Book and chapter ranges ------------------------------------------------

  # One track per span of chapters within a part: matched on the numbers
  # both sides carry, the chapter's part ("The Third Book" is 3) and its
  # heading ("Chapter XXV" is 25), never by counting forward.
  defp book_chapter_ranges(chapters, tracks) do
    spans =
      for {track, index} <- Enum.with_index(tracks),
          is_binary(track.title),
          span = span(track.title),
          span != nil,
          do: Map.put(span, :track, index)

    if spans == [] do
      Alignment.empty()
    else
      found =
        chapters
        |> Enum.with_index()
        |> Enum.map(fn {chapter, index} ->
          with part when is_binary(part) <- chapter.part,
               book when book != nil <- number(part),
               n when n != nil <- number(chapter.heading),
               %{track: track} <-
                 Enum.find(spans, &(&1.book == book and n >= &1.first and n <= &1.last)) do
            {index, track}
          else
            _none -> {index, nil}
          end
        end)

      chapter_to_track = Enum.map(found, &elem(&1, 1))

      track_to_chapters =
        found
        |> Enum.reject(fn {_index, track} -> track == nil end)
        |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
        |> Map.new(fn {track, indexes} -> {track, Enum.min(indexes)..Enum.max(indexes)} end)

      Alignment.new(chapter_to_track, track_to_chapters)
    end
  end

  # "Book 1 - Chapters 11-20": book 1, 11 through 20.
  defp span(title) do
    with [_all, book, first, last] <- Regex.run(@span, title),
         book when book != nil <- span_value(book),
         first when first != nil <- span_value(first),
         last when last != nil and last >= first <- span_value(last) do
      %{book: book, first: first, last: last}
    else
      _no_span -> nil
    end
  end

  defp span_value(token) do
    case Integer.parse(token) do
      {n, ""} -> n
      _roman -> roman(token)
    end
  end

  # -- Numerals (LibraryNumerals) ---------------------------------------------

  @written %{
    "first" => 1,
    "second" => 2,
    "third" => 3,
    "fourth" => 4,
    "fifth" => 5,
    "sixth" => 6,
    "seventh" => 7,
    "eighth" => 8,
    "ninth" => 9,
    "tenth" => 10,
    "eleventh" => 11,
    "twelfth" => 12,
    "thirteenth" => 13,
    "one" => 1,
    "two" => 2,
    "three" => 3,
    "four" => 4,
    "five" => 5,
    "six" => 6,
    "seven" => 7,
    "eight" => 8,
    "nine" => 9,
    "ten" => 10,
    "eleven" => 11,
    "twelve" => 12,
    "thirteen" => 13
  }

  @roman_values %{
    "I" => 1,
    "V" => 5,
    "X" => 10,
    "L" => 50,
    "C" => 100,
    "D" => 500,
    "M" => 1000
  }

  # No book on the shelf runs past 114 chapters nor a part past 13, so a
  # reading beyond this is a word that happens to scan ("MIX").
  @plausible_limit 200

  @doc ~S"""
  The first number in a string, however it is written: "Chapter XI" is
  11, "Book 3 - Chapters 1-10" is 3, "The First Book" is 1.
  """
  def number(text), do: text |> tokens() |> Enum.find_value(&numeral/1)

  @doc """
  The number after the word "Book", not merely the first in the line:
  "Book Four, Chapters 1-10" names book four.
  """
  def book_number(text) do
    text
    |> tokens()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find_value(fn [token, next] ->
      if String.starts_with?(String.downcase(token), "book"), do: numeral(next)
    end)
  end

  @doc "One token as a number: \"3\", \"III\", \"Third\" or \"Three\"."
  def numeral(token) do
    case Integer.parse(token) do
      {n, ""} -> n
      _other -> roman(token) || ordinal_word(token)
    end
  end

  @doc """
  A Roman numeral as the sources print it: uppercase, written the
  canonical way, and no more than 200, so a word spelled in a numeral's
  letters ("DID", "CIVIL", "MIX") is never one.
  """
  def roman(token) do
    cleaned = trim_stops(token)
    letters = String.graphemes(cleaned)

    with true <- cleaned != "" and cleaned == String.upcase(cleaned),
         true <- Enum.all?(letters, &Map.has_key?(@roman_values, &1)),
         total = subtractive(Enum.map(letters, &@roman_values[&1])),
         true <- total > 0 and total <= @plausible_limit,
         true <- roman_numeral(total) == cleaned do
      total
    else
      _not_a_numeral -> nil
    end
  end

  @doc "A number as it would be printed: 14 is \"XIV\"."
  def roman_numeral(number) do
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

  defp ordinal_word(token), do: @written[token |> trim_stops() |> String.downcase()]

  defp trim_stops(token), do: trim_chars(token)

  defp trim_chars(token) do
    trimmed =
      token
      |> String.trim_leading(".")
      |> String.trim_leading(",")
      |> String.trim_leading(":")
      |> String.trim_leading(";")
      |> String.trim_trailing(".")
      |> String.trim_trailing(",")
      |> String.trim_trailing(":")
      |> String.trim_trailing(";")

    if trimmed == token, do: token, else: trim_chars(trimmed)
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

  # Words and numerals: runs of letters and digits.
  defp tokens(text), do: Regex.split(~r/[^\p{L}\p{N}]+/u, text, trim: true)
end
