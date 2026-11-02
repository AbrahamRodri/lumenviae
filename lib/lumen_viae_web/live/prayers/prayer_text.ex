defmodule LumenViaeWeb.Live.Prayers.PrayerText do
  @moduledoc """
  The small grammar a Prayer Book prayer's text carries, read for the
  page, as the iOS app reads it (`PrayerMarkup` and `BilingualText`; the
  Android app's `PrayerText.kt` line for line). Every rule is a mark a
  printed prayer book already uses:

    * a blank line ends a stanza;
    * a line wholly in square brackets is a rubric, a direction never
      prayed as text, set in red italic;
    * the glyphs ℣, ℟ and ✠ are set in red wherever they fall;
    * "Holy Mary, ℟. pray for us." is a litany's invocation and response;
    * " * " points a psalm verse at its mediant.

  In Both the Latin and the English pair line for line: a line the same in
  both ("Amen.") stands alone, and when the two have different numbers of
  lines they stand as two blocks, one after the other.

  Pure: `stanzas/3` turns a prayer's words into stanzas of lines, each line
  a `primary` part and, in Both, a `secondary` one, each part one of
  `{:rubric, runs}`, `{:litany, invocation_runs, response_runs}`,
  `{:pointed, first_runs, second_runs}` or `{:text, runs}`, where runs are
  `{:glyph, text}` (set in red) and `{:text, text}`.
  """

  @languages ~w(english latin both)

  @glyphs ~r/([℣℟✠])/u

  # A paragraph is one line of at least this many characters; under it a
  # lone line is verse.
  @prose_threshold 90

  @doc "The languages a prayer page offers, English first."
  def languages, do: @languages

  @doc "A language from the URL: `latin` or `both`, anything else English."
  def language(value) when value in @languages, do: value
  def language(_value), do: "english"

  @doc """
  The text as the page sets it in `language`: the English, the Latin, or
  in `"both"` the English with its Latin line by line (`|||` between). A
  prayer with no Latin is English in every language.
  """
  def formatted(english, nil, _language), do: english
  def formatted(english, _latin, "english"), do: english
  def formatted(_english, latin, "latin"), do: latin
  def formatted(english, latin, "both"), do: paired(english, latin)
  def formatted(english, _latin, _language), do: english

  @doc """
  Two texts line by line with `|||` between: when the line counts differ
  the two stand as blocks, one after the other; a line the same in both
  languages stands alone.
  """
  def paired(primary, secondary) do
    first = String.split(primary, "\n")
    second = String.split(secondary, "\n")

    if length(first) != length(second) do
      primary <> "\n\n" <> secondary
    else
      first
      |> Enum.zip(second)
      |> Enum.flat_map(fn {p, s} ->
        a = String.trim(p)
        b = String.trim(s)

        cond do
          a == "" and b == "" -> [""]
          a == "" -> []
          b == "" or String.downcase(a) == String.downcase(b) -> [a]
          true -> ["#{a}|||#{b}"]
        end
      end)
      |> Enum.join("\n")
    end
  end

  @doc """
  A prayer's words as stanzas in `language`, each
  `%{kind: :verse | :prose | :litany | :pointed | :rule, lines: [line]}`
  and each line `%{primary: part, secondary: part | nil}`.
  """
  def stanzas(english, latin, language) do
    english
    |> formatted(latin, language)
    |> String.replace("\r\n", "\n")
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.chunk_by(&(&1 == ""))
    |> Enum.reject(&(&1 == [""] or Enum.all?(&1, fn line -> line == "" end)))
    |> Enum.map(fn lines -> %{kind: kind(lines), lines: Enum.map(lines, &line/1)} end)
  end

  @doc "One line's two languages: the text prayed, and its translation after `|||`."
  def parts(line) do
    case String.split(line, "|||", parts: 2) do
      [primary] ->
        {String.trim(primary), nil}

      [primary, secondary] ->
        secondary = String.trim(secondary)
        {String.trim(primary), if(secondary == "", do: nil, else: secondary)}
    end
  end

  @doc "The shape a stanza is read in."
  def kind(lines) do
    primaries = Enum.map(lines, &elem(parts(&1), 0))

    cond do
      match?([_], lines) and rule?(hd(lines)) -> :rule
      Enum.any?(primaries, &pointed?/1) -> :pointed
      Enum.any?(primaries, &litany?/1) -> :litany
      prose?(primaries) -> :prose
      true -> :verse
    end
  end

  defp prose?([only]), do: not rubric?(only) and String.length(only) >= @prose_threshold
  defp prose?(_lines), do: false

  defp line(text) do
    {primary, secondary} = parts(text)
    %{primary: part(primary), secondary: secondary && part(secondary)}
  end

  defp part(text) do
    cond do
      rubric?(text) ->
        {:rubric, runs(String.slice(text, 1..-2//1))}

      litany?(text) ->
        [invocation, response] = String.split(text, "℟.", parts: 2)
        {:litany, runs(String.trim(invocation)), runs(String.trim(response))}

      pointed?(text) ->
        [first, second] = String.split(text, " * ", parts: 2)
        {:pointed, runs(first), runs(second)}

      true ->
        {:text, runs(text)}
    end
  end

  @doc "A line wholly in square brackets is a rubric."
  def rubric?(text) do
    String.length(text) > 2 and String.starts_with?(text, "[") and String.ends_with?(text, "]")
  end

  @doc "An invocation answered on its line; a line that opens on ℟ is a response alone, and verse."
  def litany?(text) do
    case :binary.match(text, "℟.") do
      {at, _} -> at > 0
      :nomatch -> false
    end
  end

  @doc "A verse pointed at its mediant."
  def pointed?(text), do: String.contains?(text, " * ")

  @doc "A hand-typed rule between the parts of a prayer."
  def rule?(text) do
    String.length(text) >= 3 and String.match?(text, ~r/\A[─—–\-*_ ]+\z/u)
  end

  @doc "Text cut into runs, the red glyphs apart from the words."
  def runs(text) do
    @glyphs
    |> Regex.split(text, include_captures: true, trim: true)
    |> Enum.map(fn piece ->
      if Regex.match?(@glyphs, piece) and String.length(piece) == 1,
        do: {:glyph, piece},
        else: {:text, piece}
    end)
  end
end
