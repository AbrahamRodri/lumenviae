defmodule LumenViaeWeb.Live.Hours.OfficeText do
  @moduledoc """
  One hour's sections as the reader sets them, the iOS app's
  `OfficeReaderSection` and `OfficeSectionView` (with the Missal's line
  rules they read through) line for line.

  The Office answers each section as a Latin cell and an English one, each
  with its red title ("Psalmi", "Psalms"), an optional rubric note in
  braces and its lines. A section is given an id the rail and the jump
  list address (the index rides in it, so three "Lectio"s address apart);
  one that arrives unnamed is a continuation, drawn but never listed.

  The language is the reader's choice:

    * `"english"`: the English, or the Latin where a section has none;
    * `"latin"`: the Latin, or the English where it has none;
    * `"both"`: the Latin leading and the English with it, as the Office
      is printed. Line for line where the two have as many lines (they
      nearly always do), as two blocks where they do not.

  Every line is cleaned as the app cleans it (an antiphon's "Ant." said as
  "Antiphon:", the Latin's "S." and "M." as the priest's "P." and the
  people's "S.", a bare "+" or "☩" as ✠) and cut into runs, the ℣ ℟ ✠
  marks apart to be set in red (`LumenViaeWeb.Live.Prayers.PrayerText.runs/1`)
  and a rubric in braces apart as a note.
  Pure: no fetching here.
  """

  alias LumenViaeWeb.Live.Prayers.PrayerText

  @languages ~w(english latin both)

  @doc "The languages an hour is read in, as the chooser lists them."
  def languages, do: [{"latin", "Latin"}, {"english", "English"}, {"both", "Both"}]

  @doc "A language from the link: `latin` or `both`, anything else English."
  def language(value) when value in @languages, do: value
  def language(_value), do: "english"

  @doc """
  The hour's sections, each `%{id:, index:, name:, rail_name:, note:,
  body:}`, set for `language`. `name` is the heading over the text (nil
  for a continuation), `rail_name` what the rail calls a named section,
  and `body` one of `{:single, lang, lines}`, `{:paired, [{latin,
  english}]}` or `{:blocks, latin_lines, english_lines}`, each line a list
  of runs.
  """
  def sections(sections, language) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} -> section(section, index, language) end)
  end

  @doc "The named sections, the rail's and the jump list's."
  def named(sections), do: Enum.filter(sections, & &1.name)

  defp section(section, index, language) do
    latin = Map.get(section, :latin)
    english = Map.get(section, :vernacular)
    latin_name = title(latin)
    english_name = title(english)

    %{
      id: "office-#{index}-#{slug(latin_name || english_name)}",
      index: index,
      name: display_name(latin_name, english_name, language),
      rail_name: english_name || latin_name,
      note: note(latin, english, language),
      body: body(latin, english, language)
    }
  end

  # Bilingual, the heading is the English alone, as the rail names it: the
  # text beneath already pairs the two.
  defp display_name(latin, english, "latin"), do: latin || english
  defp display_name(latin, english, _language), do: english || latin

  # The rubric note from the side being prayed, out of its braces.
  defp note(latin, english, "english"), do: clean_note(note(english) || note(latin))
  defp note(latin, english, _language), do: clean_note(note(latin) || note(english))

  defp note(%{note: note}) when is_binary(note) do
    case String.trim(note) do
      "" -> nil
      note -> note
    end
  end

  defp note(_cell), do: nil

  defp clean_note(nil), do: nil

  defp clean_note(note) do
    note |> String.trim_leading("{") |> String.trim_trailing("}") |> String.trim()
  end

  defp body(latin, english, "english"), do: single(english, latin, :english)
  defp body(latin, english, "latin"), do: single(latin, english, :latin)

  defp body(latin, english, "both") do
    latin_lines = lines(latin, :latin)
    english_lines = lines(english, :english)

    cond do
      latin_lines == [] or english_lines == [] ->
        single(latin, english, :latin)

      length(latin_lines) == length(english_lines) ->
        {:paired, Enum.zip(latin_lines, english_lines)}

      true ->
        {:blocks, latin_lines, english_lines}
    end
  end

  # The chosen side, or the other where the chosen one is empty.
  defp single(chosen, other, side) do
    case lines(chosen, side) do
      [] -> {:single, other_side(side), lines(other, other_side(side))}
      lines -> {:single, side, lines}
    end
  end

  defp other_side(:latin), do: :english
  defp other_side(:english), do: :latin

  defp lines(%{lines: lines}, side) when is_list(lines) do
    lines
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&(&1 |> String.trim() |> normalized(side)))
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&runs/1)
  end

  defp lines(_cell, _side), do: []

  # The marks apart in red, and a rubric in braces ("Incipit{omittitur}")
  # out of its braces as a `{:note, text}` run, set in red italic as a
  # printed breviary sets it.
  defp runs(line) do
    Enum.flat_map(PrayerText.runs(line), fn
      {:text, text} ->
        ~r/\{([^}]*)\}/u
        |> Regex.split(text, include_captures: true, trim: true)
        |> Enum.map(fn piece ->
          case Regex.run(~r/\A\{([^}]*)\}\z/u, piece) do
            [_, note] -> {:note, String.trim(note)}
            nil -> {:text, piece}
          end
        end)

      glyph ->
        [glyph]
    end)
  end

  @doc """
  One line as the app sets it: "Ant." said as "Antiphon:", the Latin's
  server marks as the English's, and the cross as ✠.
  """
  def normalized(line, side) do
    line
    |> speaker_marked(side)
    |> String.replace("☩", "✠")
    |> String.replace(~r/(^|\s)\+\s*/u, "\\1✠ ")
  end

  # Only at the head of a line that ends as a sentence does: a saint named
  # "S. Joánnis Baptístæ" at the head of a line is left as he is.
  defp speaker_marked("Ant. " <> rest, _side), do: "Antiphon: " <> rest

  defp speaker_marked(line, :latin) do
    cond do
      not String.ends_with?(line, [".", "!", "?", ":", ","]) -> line
      String.starts_with?(line, "S. ") -> "P. " <> String.slice(line, 3..-1//1)
      String.starts_with?(line, "M. ") -> "S. " <> String.slice(line, 3..-1//1)
      true -> line
    end
  end

  defp speaker_marked(line, _side), do: line

  defp title(%{title: title}) when is_binary(title) do
    case String.trim(title) do
      "" -> nil
      title -> title
    end
  end

  defp title(_cell), do: nil

  defp slug(nil), do: "part"

  defp slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, "-")
    |> String.trim("-")
  end
end
