defmodule LumenViaeWeb.Live.Pray.TimedText do
  @moduledoc """
  Which words on the page each timed line of a recording is.

  A recording's lines (`{text, start, end}`, from the recording itself)
  are not cut where the page breaks its words: the Hail Mary is six lines
  on the page and four in its timings, and a meditation's narration may
  differ from the page by a word ("For we behold" read as "We behold").
  So each timed line is found by the last words it ends on, in order,
  and owns the page's words from where the line before it ended to there.

  The page keeps its own lines and paragraphs; each is cut into segments,
  `{text, line}`, where `line` is the timed line's index. A timed line
  that cannot be found leaves it and the rest unlit (`nil`): a line is lit
  only where the recording says it is read, never at a guessed pace.
  """

  # Enough words to find a line's end, few enough that a changed word
  # near its end rarely loses it.
  @tail 3

  @doc """
  Cuts `blocks` (the page's lines, in order) into `{text, line}`
  segments for the timed `lines`. Returns nil when there are no timed
  lines, or when not even the first one can be found: the words are then
  shown as they are, unlit.

      iex> segments(["Hail Mary, full of grace,", "the Lord is with thee."],
      ...>   [%{text: "Hail Mary, full of grace, the Lord is with thee."}])
      [[{"Hail Mary, full of grace,", 0}], [{"the Lord is with thee.", 0}]]
  """
  @spec segments([String.t()], [map] | nil) :: [[{String.t(), non_neg_integer | nil}]] | nil
  def segments(_blocks, nil), do: nil
  def segments(_blocks, []), do: nil

  def segments(blocks, lines) do
    tokens =
      for {block, b} <- Enum.with_index(blocks),
          word <- String.split(block),
          do: {b, word, normalize(word)}

    owners = assign(tokens, Enum.map(lines, &tail(line_text(&1))), 0, 0, [])

    if Enum.all?(owners, &is_nil/1) do
      nil
    else
      tokens
      |> Enum.zip(owners)
      |> Enum.group_by(fn {{b, _, _}, _} -> b end)
      |> then(fn by_block ->
        for b <- 0..(length(blocks) - 1)//1 do
          by_block |> Map.get(b, []) |> join_runs()
        end
      end)
    end
  end

  # For each token, the index of the timed line it belongs to, or nil.
  defp assign(tokens, [], _line, _at, acc),
    do: Enum.reverse(acc) ++ List.duplicate(nil, length(tokens) - length(acc))

  defp assign(tokens, [tail | rest], line, at, acc) do
    case find_end(tokens, tail, at) do
      nil ->
        Enum.reverse(acc) ++ List.duplicate(nil, length(tokens) - length(acc))

      last ->
        acc = List.duplicate(line, last - at + 1) ++ acc
        assign(tokens, rest, line + 1, last + 1, acc)
    end
  end

  # The index of the last token of the first run, at or after `at`, whose
  # words are `tail`.
  defp find_end(_tokens, [], _at), do: nil

  defp find_end(tokens, tail, at) do
    # A word with no letters (a dash standing alone) is not spoken, so it
    # is not looked for; a run may step over it.
    spoken =
      tokens
      |> Enum.with_index()
      |> Enum.drop(at)
      |> Enum.reject(fn {{_, _, word}, _} -> word == "" end)

    size = length(tail)

    spoken
    |> Enum.chunk_every(size, 1, :discard)
    |> Enum.find(fn run -> Enum.map(run, fn {{_, _, word}, _} -> word end) == tail end)
    |> case do
      nil -> nil
      run -> run |> List.last() |> elem(1)
    end
  end

  defp join_runs(tokens) do
    tokens
    |> Enum.chunk_by(fn {_token, line} -> line end)
    |> Enum.map(fn [{_, line} | _] = run ->
      {run |> Enum.map(fn {{_, word, _}, _} -> word end) |> Enum.join(" "), line}
    end)
  end

  defp tail(text) do
    text
    |> String.split()
    |> Enum.map(&normalize/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(-@tail)
  end

  defp line_text(%{text: text}), do: text
  defp line_text(%{"text" => text}), do: text

  # A word as spoken: its letters and digits, lower case.
  defp normalize(word),
    do: word |> String.downcase() |> String.replace(~r/[^\p{L}\p{N}]/u, "")
end
