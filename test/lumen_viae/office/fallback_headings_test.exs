defmodule LumenViae.Office.FallbackHeadingsTest do
  @moduledoc """
  Divinum Officium prints a heading in English where its Spanish file has
  no translation; the Office puts those few into Spanish, and touches
  nothing else.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Office.FallbackHeadings

  defp section(vernacular),
    do: %{
      latin: %{title: "Ad Nocturnum", note: nil, lines: ["Ad Nocturnum"]},
      vernacular: vernacular
    }

  test "the Spanish Matins' At the Nocturn line becomes En el Nocturno" do
    [translated] =
      FallbackHeadings.translate(
        [
          section(%{
            title: "Salmos con lecturas",
            note: nil,
            lines: ["At the Nocturn", "Ant. Eres el más bello"]
          })
        ],
        "espanol"
      )

    assert translated.vernacular.lines == ["En el Nocturno", "Ant. Eres el más bello"]
    assert translated.vernacular.title == "Salmos con lecturas"
    assert translated.latin.lines == ["Ad Nocturnum"]
  end

  test "the Spanish Prime's English section titles are translated" do
    sections = [
      section(%{title: "Martyrology", note: nil, lines: ["Año del Señor 2026"]}),
      section(%{title: "The Capitular Office", note: nil, lines: []})
    ]

    assert ["Martirologio", "Oficio capitular"] ==
             sections |> FallbackHeadings.translate("espanol") |> Enum.map(& &1.vernacular.title)
  end

  test "only a whole line is replaced, and other languages are left alone" do
    line = "Read at the Nocturn of the day"

    [kept] =
      FallbackHeadings.translate([section(%{title: nil, note: nil, lines: [line]})], "espanol")

    assert kept.vernacular.lines == [line]

    english = [section(%{title: "Martyrology", note: nil, lines: ["At the Nocturn"]})]
    assert FallbackHeadings.translate(english, "english") == english
  end

  test "a section without a vernacular column passes through" do
    bare = [%{latin: %{title: "Ad Nocturnum", note: nil, lines: []}, vernacular: nil}]
    assert FallbackHeadings.translate(bare, "espanol") == bare
  end
end
