defmodule LumenViae.Office.ParserTest do
  @moduledoc """
  The parser against real pages saved from divinumofficium.com, so the
  expectations encode the engine's actual markup rather than a guess at
  it. If the engine reshapes its output, these fixtures are where the
  breakage shows first.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Office.Parser

  @fixtures Path.expand("../../support/fixtures/divinum_officium", __DIR__)

  defp fixture(name), do: File.read!(Path.join(@fixtures, name))

  describe "parse_hour/1 on Lauds" do
    setup do
      {:ok, parsed} = Parser.parse_hour(fixture("laudes_2026-08-24.html"))
      %{parsed: parsed}
    end

    test "reads the day's celebration and rank off the masthead", %{parsed: parsed} do
      assert parsed.celebration == %{title: "S. Bartholomæi Apostoli", rank: "II. classis"}
    end

    test "reads the season line", %{parsed: parsed} do
      assert parsed.tempora ==
               "Feria Secunda infra Hebdomadam XIII post Octavam Pentecostes IV. Augusti"
    end

    test "finds every section row, anchored or not", %{parsed: parsed} do
      assert length(parsed.sections) == 11

      omitted = Enum.find(parsed.sections, &(&1.latin.lines == ["Preces Feriales{omittitur}"]))
      assert omitted, "the anchor-less omitted-preces rubric row must survive"
    end

    test "a section carries both columns with parallel titles", %{parsed: parsed} do
      [incipit | _rest] = parsed.sections

      assert incipit.latin.title == "Incipit"
      assert incipit.vernacular.title == "Start"
      assert length(incipit.latin.lines) == 5
      assert length(incipit.vernacular.lines) == 5
    end

    test "lines are plain text with the rubric glyphs kept", %{parsed: parsed} do
      [incipit | _rest] = parsed.sections

      assert hd(incipit.latin.lines) == "℣. Deus ✠ in adiutórium meum inténde."
      assert hd(incipit.vernacular.lines) == "℣. O God, ✠ come to my assistance;"
    end

    test "a rubric note after the title lands in :note, not in the lines", %{parsed: parsed} do
      psalmi = Enum.find(parsed.sections, &(&1.latin.title == "Psalmi"))

      assert psalmi.latin.note == "{Psalmi & antiphonæ ex Commune aut Festo}"
      assert psalmi.vernacular.note == "{Psalms & antiphons from the Common or Feast}"
    end

    test "psalm rows that open with a small Ant. font are untitled sections", %{parsed: parsed} do
      untitled = Enum.filter(parsed.sections, &is_nil(&1.latin.title))

      assert length(untitled) == 5
      assert untitled |> hd() |> Map.fetch!(:latin) |> Map.fetch!(:lines) |> hd() =~ "Ant."
    end

    test "the office ends with its conclusion", %{parsed: parsed} do
      assert List.last(parsed.sections).latin.title == "Conclusio"
    end
  end

  describe "parse_hour/1 on Matins" do
    test "parses the longest hour, nocturns and lessons included" do
      {:ok, parsed} = Parser.parse_hour(fixture("matutinum_2026-08-24.html"))

      assert length(parsed.sections) == 30

      titles = parsed.sections |> Enum.map(& &1.latin.title) |> Enum.reject(&is_nil/1)
      assert "Incipit" in titles
      assert "Invitatorium" in titles
      assert "Hymnus" in titles
    end
  end

  describe "parse_hour/1 on Vespers" do
    test "reads the anchor prefix off the page, which spells the hour differently" do
      # The engine is asked for "Vesperae" but anchors the page "Vespera1",
      # "Vespera2", ... - the prefix must come from the page itself.
      {:ok, parsed} = Parser.parse_hour(fixture("vesperae_2026-08-24.html"))

      assert length(parsed.sections) > 5
      assert hd(parsed.sections).latin.title == "Incipit"
      assert parsed.celebration.title == "S. Bartholomæi Apostoli"
    end
  end

  describe "parse_hour/1 on a Latin-only office" do
    test "a single-column page yields sections with no vernacular cell" do
      # Asking for Latin as the translation collapses the page to one
      # full-width column.
      {:ok, parsed} = Parser.parse_hour(fixture("completorium_latin_divino_afflatu.html"))

      assert length(parsed.sections) == 17
      assert Enum.all?(parsed.sections, &is_nil(&1.vernacular))
      assert Enum.at(parsed.sections, 1).latin.title == "Incipit"
    end
  end

  describe "parse_hour/1 when the page is not an office" do
    test "an arbitrary page is refused rather than half-read" do
      assert Parser.parse_hour("<html><body><p>maintenance</p></body></html>") ==
               {:error, :unparseable}
    end
  end

  describe "parse_kalendar/3" do
    setup do
      {:ok, days} = Parser.parse_kalendar(fixture("kalendar_2026-08.html"), 2026, 8)
      %{days: days}
    end

    defp on(days, day), do: Enum.find(days, &(&1.date.day == day))

    test "yields every day of the month", %{days: days} do
      assert length(days) == 31
      assert hd(days).date == ~D[2026-08-01]
    end

    test "a weekday feast: celebration in bold, season in the detail", %{days: days} do
      day = on(days, 24)

      assert day.celebration == %{title: "S. Bartholomæi Apostoli", rank: "II. classis"}
      assert day.detail.label == "Tempora"
      assert day.detail.text =~ "Feria Secunda infra Hebd XIII"
      assert day.letter == "F.II"
    end

    test "a Sunday: the celebration moves to the second column", %{days: days} do
      day = on(days, 2)

      assert day.celebration == %{
               title: "Dominica X Post Pentecosten I. Augusti",
               rank: "II. classis"
             }

      assert day.detail == nil
      assert day.letter == "Dom."
    end

    test "a commemoration line is kept verbatim under its own label", %{days: days} do
      day = on(days, 8)

      assert day.detail.label == "Commemoratio ad Laudes tantum"
      assert day.detail.text =~ "Cyriaci"
    end

    test "a rubric note survives into :note", %{days: days} do
      assert on(days, 8).note == "Vespera de sequenti; nihil de præcedenti"
      assert on(days, 24).note == nil
    end

    test "a page with no calendar rows is refused" do
      assert Parser.parse_kalendar("<html><body>nope</body></html>", 2026, 8) ==
               {:error, :unparseable}
    end
  end
end
