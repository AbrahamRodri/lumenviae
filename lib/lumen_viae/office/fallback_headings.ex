defmodule LumenViae.Office.FallbackHeadings do
  @moduledoc """
  Headings Divinum Officium has no translation for in a language, which it
  prints in English instead, put into that language.

  The engine takes a heading's vernacular from the language's
  `Psalterium/Common/Translate.txt` and, when the key is missing there,
  from the English file. Its Spanish file lacks `Ad Nocturnum`,
  `Martyrologium` and `De Officio Capituli`, so the Spanish Matins opened
  its psalms on "At the Nocturn" and the Spanish Prime titled two sections
  "Martyrology" and "The Capitular Office".

  Only a vernacular cell's title, or a whole line, that is exactly one of
  these English fallbacks is replaced; nothing else in the text is touched.
  A language with no entry here is returned unchanged.
  """

  @headings %{
    "espanol" => %{
      "At the Nocturn" => "En el Nocturno",
      "Martyrology" => "Martirologio",
      "The Capitular Office" => "Oficio capitular"
    }
  }

  @doc "The sections of an hour, with `language`'s English fallback headings translated."
  def translate(sections, language) do
    case Map.fetch(@headings, language) do
      {:ok, headings} -> Enum.map(sections, &translate_section(&1, headings))
      :error -> sections
    end
  end

  defp translate_section(%{vernacular: %{} = cell} = section, headings) do
    %{
      section
      | vernacular: %{
          cell
          | title: heading(cell.title, headings),
            lines: Enum.map(cell.lines, &heading(&1, headings))
        }
    }
  end

  defp translate_section(section, _headings), do: section

  defp heading(text, headings) when is_binary(text), do: Map.get(headings, text, text)
  defp heading(text, _headings), do: text
end
