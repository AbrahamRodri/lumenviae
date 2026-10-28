defmodule LumenViaeWeb.Live.Pray.MeditationTextTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias LumenViaeWeb.Live.Pray.PrayerText

  defp render(content) do
    render_component(&PrayerText.meditation_text/1, content: content)
    |> LazyHTML.from_fragment()
  end

  test "a blank line starts a paragraph and a single newline breaks the line" do
    doc = render("a\nb\n\nc")
    paragraphs = LazyHTML.query(doc, "p")

    assert Enum.count(paragraphs) == 2

    [first, second] = Enum.to_list(paragraphs)
    assert LazyHTML.query(first, "br") |> Enum.count() == 1
    assert LazyHTML.text(first) |> String.split() == ["a", "b"]
    assert LazyHTML.query(second, "br") |> Enum.count() == 0
    assert LazyHTML.text(second) |> String.trim() == "c"
  end

  test "Windows line ends, blank lines of spaces and stray indentation are tidied" do
    assert PrayerText.paragraphs("  Let us\r\nsee\r\n   \r\n\r\nAmen.\n\n") ==
             [["Let us", "see"], ["Amen."]]
  end

  test "no content is no paragraphs" do
    assert PrayerText.paragraphs(nil) == []
    assert PrayerText.paragraphs("\n\n") == []
  end
end
