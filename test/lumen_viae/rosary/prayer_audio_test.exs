defmodule LumenViae.Rosary.PrayerAudioTest do
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.{PrayerAudio, Voices}

  @voice %Voices.Voice{
    slug: "female",
    name: "Female",
    eleven_labs_voice_id: "voice-a",
    model_id: "eleven_v3",
    voice_settings: %{stability: 0.5, similarity_boost: 0.75}
  }

  test "the fixed prayers carry the app's ids, in the order they are said" do
    assert PrayerAudio.prayer_ids() ==
             ~w(sign_of_cross apostles_creed our_father hail_mary glory_be fatima_prayer hail_holy_queen rosary_closing_prayer)
  end

  test "every mystery has an announcement, keyed as the app keys MysteryData" do
    announcements = PrayerAudio.announcements()

    assert length(announcements) == 27
    assert hd(announcements).mystery == "joyful_1"
    assert hd(announcements).text == "The First Joyful Mystery: The Annunciation"

    sorrow = Enum.find(announcements, &(&1.mystery == "seven_sorrows_7"))
    assert sorrow.text == "The Seventh Sorrow: The Burial of Jesus"
  end

  test "a verse for every Hail Mary: ten per mystery, seven per sorrow" do
    counts = PrayerAudio.verses() |> Enum.frequencies_by(& &1.mystery)

    assert map_size(counts) == 27

    for {mystery, count} <- counts do
      expected = if String.starts_with?(mystery, "seven_sorrows"), do: 7, else: 10
      assert count == expected, "#{mystery} has #{count} verses"
    end

    first = hd(PrayerAudio.verses())
    assert first.reference == "Luke 1:26"
    assert first.bead == 1
    assert first.name == "joyful_1_1"
  end

  test "speech text joins the lines and speaks a bracketed rubric as words" do
    closing = Enum.find(PrayerAudio.prayers(), &(&1.name == "rosary_closing_prayer"))
    speech = PrayerAudio.speech_text(closing)

    assert speech =~ ~r/^Let us pray\. O God, whose only-begotten Son, by His life/
    refute speech =~ "["
    refute speech =~ "\n"
  end

  test "no clip would reach Eleven v3 carrying markup it acts on" do
    for clip <- PrayerAudio.clips() do
      refute PrayerAudio.speech_text(clip) =~ ~r/[\[\]<>{}]/, "#{clip.name} carries markup"
    end
  end

  test "keys sit under the voice's rosary prefix and are distinct" do
    keys = Enum.map(PrayerAudio.clips(), &PrayerAudio.s3_key(@voice, &1))

    assert Enum.uniq(keys) == keys

    assert Enum.find(keys, &String.contains?(&1, "/hail_mary-")) =~
             ~r"^voices/female/rosary/prayers/hail_mary-[0-9a-f]{10}\.mp3$"
  end

  test "a key changes when the words or the voice's synthesis change, and only then" do
    [clip | _] = PrayerAudio.prayers()
    key = PrayerAudio.s3_key(@voice, clip)

    assert PrayerAudio.s3_key(@voice, clip) == key
    refute PrayerAudio.s3_key(@voice, %{clip | text: clip.text <> " Amen."}) == key
    refute PrayerAudio.s3_key(%{@voice | model_id: "eleven_multilingual_v2"}, clip) == key
    refute PrayerAudio.s3_key(%{@voice | voice_settings: %{stability: 0.9}}, clip) == key
  end

  test "the version fingerprints the whole catalogue" do
    clips = PrayerAudio.clips()
    version = PrayerAudio.version(@voice, clips)

    assert version =~ ~r/^[0-9a-f]{10}$/
    refute PrayerAudio.version(@voice, tl(clips)) == version
  end

  test "clips/1 narrows to the kinds asked for" do
    assert Enum.all?(PrayerAudio.clips([:prayer]), &(&1.kind == :prayer))
    assert length(PrayerAudio.clips([:prayer, :announcement])) == 8 + 27
    assert length(PrayerAudio.clips()) == 8 + 27 + 249
  end
end
