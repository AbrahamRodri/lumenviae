defmodule LumenViae.Rosary.SpiritualReading.Parser do
  @moduledoc """
  Cuts a Project Gutenberg plain-text edition into the chapters the reader
  reads, by the edition's rules in the catalogue
  (`priv/library/spiritual_reading.json`). A port, line for line, of the
  iOS app's `LibraryBookParser` (and Android's copy of it), so the website
  cuts every book into the same chapters as the apps: a chapter's index is
  the same identity on all three.

  Gutenberg plain text is hard-wrapped at about 72 columns with blank lines
  between paragraphs, opens with a licensing header and closes with a
  licensing footer. The parser trims both, drops the front matter at the
  edition's `start_pattern`, walks the body matching the edition's heading
  patterns, rejects contents-page lines by the length under them, lifts
  each chapter's printed title, unwraps the hard-wrapped lines into whole
  paragraphs, and lifts the editor's footnotes out of the prose.

  Deterministic: the same text and rules always cut the same chapters.
  Lengths are counted in graphemes, as Swift counts a `String`.
  """

  @label ~r/^(CHAPTER|BOOK|PART|SECTION|MEDITATION|DISCOURSE)\s+([IVXLC]+)\.?(?:\s+(.*))?$/u
  @roman_word ~r/^[IVXLC]+\.?,?$/u
  @envelope_start ~r/\*\*\* START OF TH(E|IS) PROJECT GUTENBERG EBOOK/
  @envelope_end ~r/\*\*\* END OF TH(E|IS) PROJECT GUTENBERG EBOOK/
  @separator ~r/^[_\*\s]*$/u
  @emphasis ~r/_([^_]+)_/u

  # The words a printer sets lowercase inside a title: conjunctions,
  # articles and the short prepositions, nothing longer.
  @small_words ~w(a an and as at but by for from in into nor of on or over the to unto upon with)

  @doc """
  Cuts `text` by `info`'s rules (a catalogue book: `parsing`,
  `chapter_titles`, `heading_overrides`). Answers
  `%{book_id:, chapters: [%{id:, part:, heading:, title:, paragraphs:, notes:}]}`,
  `id` the chapter's index from 0.
  """
  def parse(text, info) do
    rules = info.parsing

    # Gutenberg serves CRLF; blank lines are what paragraphs and titles
    # stand on, so normalize before anything looks at a line.
    lines =
      text
      |> strip_envelope()
      |> String.replace("\r\n", "\n")
      |> String.replace("\r", "\n")
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> drop_front_matter(compile(rules.start_pattern))

    raw =
      walk(lines, %{
        chapter: compile(rules.chapter_pattern),
        part: compile(rules.part_pattern),
        stop: compile(rules.stop_pattern),
        drop: compile(rules.drop_pattern),
        minimum: rules.minimum_chapter_length
      })

    chapters =
      Enum.reduce(raw, [], fn candidate, chapters ->
        case cut(candidate, rules, info, length(chapters)) do
          nil -> chapters
          chapter -> [chapter | chapters]
        end
      end)

    %{book_id: info.id, chapters: Enum.reverse(chapters)}
  end

  # Everything above the book proper is dropped; the start line is kept,
  # as it is usually the first heading.
  defp drop_front_matter(lines, nil), do: lines

  defp drop_front_matter(lines, start) do
    case Enum.find_index(lines, &matches?(start, &1)) do
      nil -> lines
      first -> Enum.drop(lines, first)
    end
  end

  # The headings and the lines under each, as `{heading, part, lines}` in
  # order. The stop line ends the book only once the body has begun (some
  # heading has gathered more than a contents entry could), so a contents
  # page naming the epilogue cannot end it before it starts.
  defp walk(lines, regexes) do
    state = %{raw: [], current: nil, part: nil, begun: false, open: 0}

    state =
      Enum.reduce_while(lines, state, fn line, state ->
        cond do
          regexes.stop && state.begun && matches?(regexes.stop, line) ->
            {:halt, state}

          # A printer's mark, not text.
          regexes.drop && matches?(regexes.drop, line) ->
            {:cont, state}

          # The part opens a unit of its own: the Imitation's Fourth Book
          # opens with an exhortation that would otherwise be dropped.
          regexes.part && matches?(regexes.part, line) ->
            part = part_name(line)
            {:cont, %{close(state) | part: part, current: {line, part, []}, open: 0}}

          regexes.chapter && matches?(regexes.chapter, line) ->
            {:cont, %{close(state) | current: {line, state.part, []}, open: 0}}

          state.current ->
            {heading, part, under} = state.current
            open = state.open + String.length(line)

            {:cont,
             %{
               state
               | current: {heading, part, [line | under]},
                 open: open,
                 begun: state.begun or open >= regexes.minimum
             }}

          true ->
            {:cont, state}
        end
      end)

    state |> close() |> Map.fetch!(:raw) |> Enum.reverse()
  end

  defp close(%{current: nil} = state), do: state

  defp close(%{current: {heading, part, under}} = state),
    do: %{state | raw: [{heading, part, Enum.reverse(under)} | state.raw], current: nil}

  # One heading's chapter, or nil where its body runs too short to be one
  # (the contents page naming it).
  defp cut({printed, part, lines}, rules, info, index) do
    body_length = Enum.reduce(lines, 0, &(String.length(&1) + &2))

    if body_length < rules.minimum_chapter_length do
      nil
    else
      {heading, title} = split_heading(printed)
      {title, lines} = lift_title(title, lines, rules)

      title =
        if title do
          title = if title == String.upcase(title), do: title_cased(title), else: title
          String.replace_suffix(title, ".", "")
        end

      # An edition that prints no titles takes the curated ones; a
      # misprinted heading its correction.
      title = curated_title(info, index, title)
      heading = corrected_heading(info, index, heading)

      {prose, notes} = split_notes(paragraphs(lines), rules.note_pattern)

      %{
        id: index,
        part: part,
        heading: heading,
        title: title,
        paragraphs: prose,
        notes: notes
      }
    end
  end

  # No inline title: the first short block after the heading is the
  # printed title. Where the edition sets it over several blocks a single
  # blank line apart (`title_runs_to_blank_gap`), they are joined.
  defp lift_title(nil, lines, rules) do
    lines = List.to_tuple(lines)

    case take_title_blocks(lines, 0, [], rules) do
      {[], _cursor} ->
        {nil, Tuple.to_list(lines)}

      {lifted, cursor} ->
        rest = lines |> Tuple.to_list() |> Enum.drop(cursor)
        {lifted |> Enum.reverse() |> Enum.join(". "), rest}
    end
  end

  defp lift_title(title, lines, _rules), do: {title, lines}

  defp take_title_blocks(lines, cursor, lifted, rules) do
    {index, gap} = skip_blank(lines, cursor, 0)

    # A second block only continues the title when the blank run before it
    # is a single line.
    if lifted != [] and not (rules.title_runs_to_blank_gap and gap == 1) do
      {lifted, cursor}
    else
      {block, finish} = take_block(lines, index, [])
      joined = block |> Enum.join(" ") |> String.replace("_", "")

      if joined == "" or String.length(joined) > rules.maximum_title_length do
        {lifted, cursor}
      else
        # Each printed block ends with its own full stop.
        lifted = [String.replace_suffix(joined, ".", "") | lifted]

        if rules.title_runs_to_blank_gap,
          do: take_title_blocks(lines, finish, lifted, rules),
          else: {lifted, finish}
      end
    end
  end

  defp skip_blank(lines, index, gap) do
    if index < tuple_size(lines) and elem(lines, index) == "",
      do: skip_blank(lines, index + 1, gap + 1),
      else: {index, gap}
  end

  defp take_block(lines, index, block) do
    if index < tuple_size(lines) and elem(lines, index) != "",
      do: take_block(lines, index + 1, [elem(lines, index) | block]),
      else: {Enum.reverse(block), index}
  end

  defp curated_title(_info, _index, title) when is_binary(title) and title != "", do: title

  defp curated_title(info, index, _title) do
    case info.chapter_titles do
      titles when is_list(titles) -> Enum.at(titles, index)
      _none -> nil
    end
  end

  defp corrected_heading(info, index, heading) do
    Enum.find_value(info.heading_overrides || [], heading, fn override ->
      if override.chapter == index, do: override.heading
    end)
  end

  @doc "Everything between the START and END licence markers."
  def strip_envelope(text) do
    text =
      case Regex.run(@envelope_start, text, return: :index) do
        [{start, length} | _groups] ->
          after_marker = binary_part(text, start + length, byte_size(text) - start - length)

          case :binary.match(after_marker, "\n") do
            {line_end, 1} ->
              binary_part(after_marker, line_end + 1, byte_size(after_marker) - line_end - 1)

            :nomatch ->
              text
          end

        nil ->
          text
      end

    case Regex.run(@envelope_end, text, return: :index) do
      [{finish, _length} | _groups] -> binary_part(text, 0, finish)
      nil -> text
    end
  end

  @doc """
  `"CHAPTER V VOCATION OF THÉRÈSE"` is `{"Chapter V", "VOCATION OF THÉRÈSE"}`;
  `"BOOK I"` is `{"Book I", nil}`; anything else is its own heading, split
  at a colon when it carries one, its closing stop dropped
  (`"FIRST LETTER."` is `"First Letter"`). Underscores are read out.
  """
  def split_heading(printed) do
    line = printed |> String.replace("_", "") |> String.trim()

    case Regex.run(@label, line) do
      [_all, label, numeral | inline] ->
        inline = inline |> List.first() |> then(&if(&1, do: String.trim(&1)))
        {"#{String.capitalize(label)} #{numeral}", if(inline in [nil, ""], do: nil, else: inline)}

      nil ->
        case String.split(line, ":", parts: 2) do
          [head, rest] ->
            rest = String.trim(rest)
            {title_cased(String.trim(head)), if(rest == "", do: nil, else: rest)}

          [_whole] ->
            {title_cased(String.replace_suffix(line, ".", "")), nil}
        end
    end
  end

  @doc ~S("THE FIRST BOOK." is "The First Book"; "PART SECOND:" is "Part Second".)
  def part_name(line) do
    line
    |> String.replace("_", "")
    |> String.trim()
    |> trim_trailing_stops()
    |> title_cased()
  end

  defp trim_trailing_stops(name) do
    trimmed = name |> String.trim_trailing(".") |> String.trim_trailing(":")
    if trimmed == name, do: name, else: trim_trailing_stops(trimmed)
  end

  @doc """
  `"PAULINE ENTERS THE CARMEL"` is `"Pauline Enters the Carmel"`: numerals
  as printed, the small words lowercase except where they open or close
  the line.
  """
  def title_cased(line) do
    words = String.split(line, " ", trim: true)
    last = length(words) - 1

    if words == [] do
      line
    else
      words
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {word, index} ->
        cond do
          Regex.match?(@roman_word, word) ->
            word

          index == 0 or index == last ->
            capitalize(word)

          true ->
            cased = capitalize(word)
            bare = cased |> String.replace(~r/^[^\p{L}]+|[^\p{L}]+$/u, "") |> String.downcase()
            if bare in @small_words, do: String.downcase(cased), else: cased
        end
      end)
    end
  end

  # Each piece of a hyphenated word capitalized, as iOS's
  # `localizedCapitalized` sets it ("Peace-Maker").
  defp capitalize(word),
    do: word |> String.split("-") |> Enum.map_join("-", &String.capitalize/1)

  # -- Footnotes ------------------------------------------------------------

  # A paragraph that opens with the edition's footnote marker is a note;
  # the rest is the book. A paragraph carrying several notes is cut at each.
  defp split_notes(paragraphs, nil), do: {paragraphs, []}

  defp split_notes(paragraphs, pattern) do
    with marker when not is_nil(marker) <- compile(pattern),
         opening when not is_nil(opening) <- compile("^(?:#{pattern})") do
      {prose, notes} =
        Enum.reduce(paragraphs, {[], []}, fn paragraph, {prose, notes} ->
          if matches?(opening, paragraph),
            do: {prose, Enum.reverse(divide(paragraph, marker), notes)},
            else: {[paragraph | prose], notes}
        end)

      {Enum.reverse(prose), Enum.reverse(notes)}
    else
      _bad_pattern -> {paragraphs, []}
    end
  end

  # Cuts a paragraph at each real marker: one opening the paragraph or
  # following a space, numbered one past the last, so a psalm's other
  # numbering ("Ps. 88[89]:1") is left alone.
  defp divide(paragraph, marker) do
    found =
      for [{start, length}] <- Regex.scan(marker, paragraph, return: :index),
          digits = paragraph |> binary_part(start, length) |> String.replace(~r/\D/, ""),
          digits != "",
          do: {start, String.to_integer(digits)}

    case found do
      [{0, number} | rest] ->
        {starts, _expected} =
          Enum.reduce(rest, {[0], number + 1}, fn {start, n}, {starts, expected} ->
            if n == expected and start > 0 and binary_part(paragraph, start - 1, 1) == " ",
              do: {[start | starts], expected + 1},
              else: {starts, expected}
          end)

        pieces(paragraph, Enum.reverse(starts))

      _no_opening ->
        [paragraph]
    end
  end

  defp pieces(paragraph, [_only]), do: [paragraph]

  defp pieces(paragraph, starts) do
    ends = Enum.drop(starts, 1) ++ [byte_size(paragraph)]

    starts
    |> Enum.zip(ends)
    |> Enum.map(fn {from, to} -> paragraph |> binary_part(from, to - from) |> String.trim() end)
    |> Enum.reject(&(&1 == ""))
  end

  # Blank-line blocks become paragraphs; the hard-wrapped lines of each
  # block join back into one. Separator rules fall away and _emphasis_ is
  # unwrapped.
  defp paragraphs(lines) do
    {paragraphs, block} =
      Enum.reduce(lines, {[], []}, fn line, {paragraphs, block} ->
        if Regex.match?(@separator, line),
          do: {close_paragraph(block, paragraphs), []},
          else: {paragraphs, [line | block]}
      end)

    block |> close_paragraph(paragraphs) |> Enum.reverse()
  end

  defp close_paragraph([], paragraphs), do: paragraphs

  defp close_paragraph(block, paragraphs) do
    text =
      block
      |> Enum.reverse()
      |> Enum.join(" ")
      |> then(&Regex.replace(@emphasis, &1, "\\1"))
      |> String.replace("_", "")

    [text | paragraphs]
  end

  # -- Patterns -------------------------------------------------------------

  defp compile(nil), do: nil

  defp compile(pattern) do
    case Regex.compile(pattern, "u") do
      {:ok, regex} -> regex
      {:error, _reason} -> nil
    end
  end

  defp matches?(_regex, ""), do: false
  defp matches?(regex, line), do: Regex.match?(regex, line)
end
