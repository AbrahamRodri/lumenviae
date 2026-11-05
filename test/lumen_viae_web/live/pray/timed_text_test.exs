defmodule LumenViaeWeb.Live.Pray.TimedTextTest do
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.PrayerAudio
  alias LumenViae.Rosary.Voices
  alias LumenViaeWeb.Live.Pray.{Sequence, TimedText}

  doctest TimedText, import: true

  defp line(text), do: %{text: text, start: 0.0, end: 1.0}

  test "a timed line spanning two of the page's lines lights both" do
    page = ["Hail Mary, full of grace, the Lord is with thee;", "blessed art thou among women,"]

    lines = [
      line("Hail Mary, full of grace, the Lord is with thee;"),
      line("blessed art thou among women,")
    ]

    assert TimedText.segments(page, lines) == [
             [{"Hail Mary, full of grace, the Lord is with thee;", 0}],
             [{"blessed art thou among women,", 1}]
           ]
  end

  test "a page line holding the end of one timed line and the start of the next is cut" do
    page = ["We behold the Lord. He came to the river.", "And was baptized."]
    lines = [line("We behold the Lord."), line("He came to the river. And was baptized.")]

    assert TimedText.segments(page, lines) == [
             [{"We behold the Lord.", 0}, {"He came to the river.", 1}],
             [{"And was baptized.", 1}]
           ]
  end

  test "a narration that reads the page a little differently is still found by its ends" do
    page = ["For we behold and see as it were in a divine spectacle."]
    lines = [line("We behold and see as it were in a divine spectacle.")]

    assert TimedText.segments(page, lines) == [
             [{"For we behold and see as it were in a divine spectacle.", 0}]
           ]
  end

  test "a line that cannot be found leaves it and the rest unlit, never a guess" do
    page = ["The first line is here.", "The second is not timed as written."]
    lines = [line("The first line is here."), line("Something else entirely.")]

    assert TimedText.segments(page, lines) == [
             [{"The first line is here.", 0}],
             [{"The second is not timed as written.", nil}]
           ]
  end

  test "no timings, or none that can be found, is nil: the words are shown as they are" do
    assert TimedText.segments(["Amen."], nil) == nil
    assert TimedText.segments(["Amen."], []) == nil
    assert TimedText.segments(["Amen."], [line("Nothing like it at all.")]) == nil
  end

  test "every timed English prayer is found in the page's own words" do
    voice = Voices.default()

    for clip <- PrayerAudio.prayers(), lines = PrayerAudio.lines(voice, clip) do
      words = for {:line, text} <- Sequence.prayer_lines(clip.name, "en"), do: text
      segments = TimedText.segments(words, lines)

      assert segments, "#{clip.name}: no timed line found on the page"

      lit = segments |> List.flatten() |> Enum.map(&elem(&1, 1)) |> Enum.reject(&is_nil/1)
      assert Enum.uniq(lit) == Enum.to_list(0..(length(lines) - 1)), "#{clip.name}: lines lost"
    end
  end
end
