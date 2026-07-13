defmodule LumenViae.Audio.TtsTextTest do
  use ExUnit.Case, async: false

  alias LumenViae.Audio.TtsText

  describe "extract_pauses/1" do
    test "returns marker-free content byte-identical, with no annotations" do
      content = "  First paragraph.\n\nSecond paragraph.\n"

      assert {:ok, ^content, []} = TtsText.extract_pauses(content)
    end

    test "strips an inline marker, collapsing to a single space" do
      assert {:ok, clean, annotations} =
               TtsText.extract_pauses("Consider this well. {pause:2} And now go forth.")

      assert clean == "Consider this well. And now go forth."
      assert annotations == [%{"offset" => 19, "seconds" => 2.0}]
    end

    test "a marker on its own line between two paragraphs leaves exactly one paragraph break" do
      assert {:ok, clean, annotations} =
               TtsText.extract_pauses("First paragraph.\n\n{pause:2.5}\n\nSecond paragraph.")

      assert clean == "First paragraph.\n\nSecond paragraph."
      assert annotations == [%{"offset" => 16, "seconds" => 2.5}]
    end

    test "a marker at the start of a paragraph keeps the paragraph break" do
      assert {:ok, clean, annotations} =
               TtsText.extract_pauses("First.\n\n{pause:1.5}Second.")

      assert clean == "First.\n\nSecond."
      assert annotations == [%{"offset" => 6, "seconds" => 1.5}]
    end

    test "markers at the very start and very end leave no stray whitespace" do
      assert {:ok, "Begin.", [%{"offset" => 0, "seconds" => 2.0}]} =
               TtsText.extract_pauses("{pause:2} Begin.")

      assert {:ok, "End.", [%{"offset" => 4, "seconds" => 2.0}]} =
               TtsText.extract_pauses("End. {pause:2}")
    end

    test "caps marker durations at 3 seconds" do
      assert {:ok, _clean, [%{"seconds" => 3.0}]} = TtsText.extract_pauses("A. {pause:5} B.")
      assert {:ok, _clean, [%{"seconds" => 3.0}]} = TtsText.extract_pauses("A. {pause:3.5} B.")
      assert {:ok, _clean, [%{"seconds" => 3.0}]} = TtsText.extract_pauses("A. {pause:3} B.")
    end

    test "tolerates spacing and case inside the marker" do
      assert {:ok, "A. B.", [%{"offset" => 2, "seconds" => 1.5}]} =
               TtsText.extract_pauses("A. {Pause: 1.5 } B.")
    end

    test "offsets are grapheme-based for accented content" do
      assert {:ok, clean, [%{"offset" => 10, "seconds" => 1.0}]} =
               TtsText.extract_pauses("Ave María. {pause:1} Grátia plena.")

      assert clean == "Ave María. Grátia plena."
      assert String.slice(clean, 0, 10) == "Ave María."
    end

    test "records multiple markers in order" do
      assert {:ok, clean, annotations} =
               TtsText.extract_pauses("One. {pause:1} Two.\n\n{pause:2}\n\nThree.")

      assert clean == "One. Two.\n\nThree."

      assert annotations == [
               %{"offset" => 4, "seconds" => 1.0},
               %{"offset" => 9, "seconds" => 2.0}
             ]
    end

    test "rejects malformed pause markers" do
      assert {:error, message} = TtsText.extract_pauses("Text {pause:soon} more text.")
      assert message =~ "invalid pause marker"
      assert message =~ "{pause:soon}"

      assert {:error, _message} = TtsText.extract_pauses("Text {pause:} more text.")
      assert {:error, _message} = TtsText.extract_pauses("Text {pause} more text.")
      assert {:error, _message} = TtsText.extract_pauses("Text {pause:-1} more text.")
    end

    test "rejects literal <break tags regardless of case or spacing" do
      assert {:error, message} = TtsText.extract_pauses(~s(Text <break time="1s" /> more.))
      assert message =~ "<break"

      assert {:error, _message} = TtsText.extract_pauses("Text <BREAK/> more.")
      assert {:error, _message} = TtsText.extract_pauses("Text < break /> more.")
    end
  end

  describe "to_speech_text/3" do
    test "converts each paragraph break to the default break tag" do
      assert TtsText.to_speech_text("First paragraph.\n\nSecond paragraph.\n\nThird.") ==
               ~s(First paragraph. <break time="1.2s" /> Second paragraph. <break time="1.2s" /> Third.)
    end

    test "leaves single newlines alone" do
      assert TtsText.to_speech_text("Line one.\nLine two.") == "Line one.\nLine two."
    end

    test "inserts annotated pauses at their offsets" do
      {:ok, clean, annotations} =
        TtsText.extract_pauses("Consider this well. {pause:2} And now go forth.")

      assert TtsText.to_speech_text(clean, annotations) ==
               ~s(Consider this well. <break time="2s" /> And now go forth.)
    end

    test "an annotation at a paragraph break replaces the default pause instead of stacking" do
      {:ok, clean, annotations} =
        TtsText.extract_pauses("First paragraph.\n\n{pause:2.5}\n\nSecond paragraph.")

      speech = TtsText.to_speech_text(clean, annotations)

      assert speech ==
               ~s(First paragraph. <break time="2.5s" /> Second paragraph.)

      refute speech =~ "1.2s"
      assert length(String.split(speech, "<break")) - 1 == 1
    end

    test "mixes default and custom pauses across paragraphs" do
      {:ok, clean, annotations} =
        TtsText.extract_pauses("One.\n\nTwo. {pause:0.5} Still two.\n\nThree.")

      assert TtsText.to_speech_text(clean, annotations) ==
               ~s(One. <break time="1.2s" /> Two. <break time="0.5s" /> Still two. <break time="1.2s" /> Three.)
    end

    test "honors the :paragraph_break_seconds option" do
      assert TtsText.to_speech_text("A.\n\nB.", [], paragraph_break_seconds: 0.8) ==
               ~s(A. <break time="0.8s" /> B.)
    end

    test "reads the default duration from application config" do
      original = Application.get_env(:lumen_viae, :tts_paragraph_break_seconds)
      Application.put_env(:lumen_viae, :tts_paragraph_break_seconds, 2)

      on_exit(fn ->
        Application.put_env(:lumen_viae, :tts_paragraph_break_seconds, original)
      end)

      assert TtsText.to_speech_text("A.\n\nB.") == ~s(A. <break time="2s" /> B.)
    end

    test "caps configured and annotated durations at 3 seconds" do
      assert TtsText.to_speech_text("A.\n\nB.", [], paragraph_break_seconds: 10) ==
               ~s(A. <break time="3s" /> B.)

      assert TtsText.to_speech_text("A. B.", [%{"offset" => 2, "seconds" => 9.9}]) ==
               ~s(A. <break time="3s" /> B.)
    end

    test "ignores malformed annotations and clamps offsets past the end" do
      assert TtsText.to_speech_text("Hi.", [%{"bogus" => true}, nil]) == "Hi."

      assert TtsText.to_speech_text("Hi.", [%{"offset" => 99, "seconds" => 1.0}]) ==
               ~s(Hi. <break time="1s" />)
    end
  end
end
