defmodule LumenViaeWeb.Live.Prayers.PrayerTextTest do
  @moduledoc """
  The Prayer Book's text grammar, as the apps read it: stanzas, rubrics,
  the red glyphs, litany and pointed lines, and Both's pairing.
  """
  use ExUnit.Case, async: true

  alias LumenViaeWeb.Live.Prayers.PrayerText

  describe "language/1" do
    test "takes latin and both, and anything else is English" do
      assert PrayerText.language("latin") == "latin"
      assert PrayerText.language("both") == "both"
      assert PrayerText.language("klingon") == "english"
      assert PrayerText.language(nil) == "english"
    end
  end

  describe "stanzas/3" do
    test "a blank line ends a stanza, and runs of blank lines are one break" do
      stanzas = PrayerText.stanzas("One.\nTwo.\n\n\nThree.", nil, "english")

      assert [%{lines: [_, _]}, %{lines: [_]}] = stanzas
    end

    test "a line wholly in brackets is a rubric, without its brackets" do
      [%{lines: [line]}] = PrayerText.stanzas("[Here all genuflect.]", nil, "english")

      assert line.primary == {:rubric, [{:text, "Here all genuflect."}]}
    end

    test "a bracket inside a line is not a rubric" do
      [%{lines: [line]}] = PrayerText.stanzas("Pray [for us] now.", nil, "english")

      assert {:text, _} = line.primary
    end

    test "the glyphs are runs of their own" do
      [%{lines: [line]}] = PrayerText.stanzas("℣. Pray for us.", nil, "english")

      assert line.primary == {:text, [{:glyph, "℣"}, {:text, ". Pray for us."}]}
    end

    test "an invocation answered on its line is a litany line" do
      [%{kind: :litany, lines: [line]}] =
        PrayerText.stanzas("Holy Mary, ℟. pray for us.", nil, "english")

      assert line.primary == {:litany, [{:text, "Holy Mary,"}], [{:text, "pray for us."}]}
    end

    test "a line that opens on its response is verse, not litany" do
      [%{kind: :verse}] = PrayerText.stanzas("℟. Amen.", nil, "english")
    end

    test "a pointed verse splits at its star" do
      [%{kind: :pointed, lines: [line]}] =
        PrayerText.stanzas("Magnificat * anima mea Dominum.", nil, "english")

      assert line.primary == {:pointed, [{:text, "Magnificat"}], [{:text, "anima mea Dominum."}]}
    end

    test "one long line is prose, a short one verse" do
      long = String.duplicate("word ", 20)
      assert [%{kind: :prose}] = PrayerText.stanzas(long, nil, "english")
      assert [%{kind: :verse}] = PrayerText.stanzas("Amen.", nil, "english")
    end

    test "a prayer with no Latin is English in every language" do
      assert PrayerText.stanzas("Amen.", nil, "both") ==
               PrayerText.stanzas("Amen.", nil, "english")
    end

    test "Latin alone" do
      [%{lines: [line]}] = PrayerText.stanzas("Hail Mary.", "Ave Maria.", "latin")

      assert line == %{primary: {:text, [{:text, "Ave Maria."}]}, secondary: nil}
    end
  end

  describe "Both" do
    test "pairs the Latin with its English line by line, Latin first" do
      [%{lines: [first, second]}] =
        PrayerText.stanzas("Hail Mary,\nfull of grace.", "Ave Maria,\ngratia plena.", "both")

      assert first == %{
               primary: {:text, [{:text, "Ave Maria,"}]},
               secondary: {:text, [{:text, "Hail Mary,"}]}
             }

      assert second.secondary == {:text, [{:text, "full of grace."}]}
    end

    test "a line the same in both languages stands alone" do
      [%{lines: [_, amen]}] = PrayerText.stanzas("Hail Mary.\nAmen.", "Ave Maria.\nAmen.", "both")

      assert amen == %{primary: {:text, [{:text, "Amen."}]}, secondary: nil}
    end

    test "keeps the stanza breaks both languages share" do
      stanzas = PrayerText.stanzas("One.\n\nTwo.", "Unum.\n\nDuo.", "both")

      assert length(stanzas) == 2
      assert Enum.all?(stanzas, fn %{lines: [line]} -> line.secondary end)
    end

    test "unequal line counts stand as two blocks, Latin then English" do
      stanzas = PrayerText.stanzas("One.\nTwo.", "Unum.", "both")

      assert [
               %{lines: [%{primary: {:text, [{:text, "Unum."}]}, secondary: nil}]},
               %{
                 lines: [
                   %{primary: {:text, [{:text, "One."}]}},
                   %{primary: {:text, [{:text, "Two."}]}}
                 ]
               }
             ] = stanzas
    end
  end
end
