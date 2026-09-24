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
             ~w(sign_of_cross apostles_creed our_father hail_mary glory_be fatima_prayer hail_holy_queen rosary_closing_prayer act_of_contrition sorrows_closing_prayer memorare st_michael_prayer)
  end

  test "every mystery has an announcement, keyed as the app keys MysteryData" do
    announcements = PrayerAudio.announcements()

    assert length(announcements) == 27
    assert hd(announcements).mystery == "joyful_1"
    assert hd(announcements).text == "The First Joyful Mystery: The Annunciation"

    sorrow = Enum.find(announcements, &(&1.mystery == "seven_sorrows_7"))
    assert sorrow.text == "The Seventh Sorrow of Mary: The Burial of Jesus"
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

  test "the chaplet's closing prayer speaks its rubric and keeps the Holy Spirit wording" do
    closing = Enum.find(PrayerAudio.prayers(), &(&1.name == "sorrows_closing_prayer"))
    speech = PrayerAudio.speech_text(closing)

    assert speech =~ "promises of Christ. Let us pray. Lord Jesus"
    assert speech =~ "with the Father and the Holy Spirit"
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
    assert length(PrayerAudio.clips([:prayer, :announcement])) == 12 + 27
    assert length(PrayerAudio.clips()) == 12 + 27 + 249
  end

  describe "script/3" do
    defp names(steps), do: Enum.map(steps, & &1.name)

    test "a Rosary opens with the Creed and three Hail Marys, and closes with the Hail Holy Queen" do
      steps = PrayerAudio.script("joyful", [1, 2, 3, 4, 5])

      assert Enum.take(names(steps), 7) ==
               ~w(sign_of_cross apostles_creed our_father hail_mary hail_mary hail_mary glory_be)

      assert Enum.take(names(steps), -3) ==
               ~w(hail_holy_queen rosary_closing_prayer sign_of_cross)

      assert Enum.all?(Enum.take(steps, 7), &is_nil(&1.decade))
    end

    test "each Rosary decade is announced, meditated, and ends with the Glory Be and Fatima Prayer" do
      decade = PrayerAudio.script("glorious", [1, 2, 3, 4, 5]) |> Enum.filter(&(&1.decade == 2))

      assert names(decade) ==
               ["glorious_3", "glorious_3", "our_father"] ++
                 List.duplicate("hail_mary", 10) ++ ["glory_be", "fatima_prayer"]

      assert [
               %{kind: :announcement, caption: "The Third Glorious Mystery: " <> _},
               %{kind: :meditation} | _
             ] =
               decade
    end

    test "the Seven Sorrows chaplet is the Servite form" do
      steps = PrayerAudio.script("seven_sorrows", Enum.to_list(1..7))

      assert Enum.take(names(steps), 2) == ~w(sign_of_cross act_of_contrition)
      refute "fatima_prayer" in names(steps)
      refute "apostles_creed" in names(steps)

      sorrow = Enum.filter(steps, &(&1.decade == 0))

      assert names(sorrow) ==
               ["seven_sorrows_1", "seven_sorrows_1", "our_father"] ++
                 List.duplicate("hail_mary", 7) ++ ["glory_be"]

      assert Enum.take(names(steps), -5) ==
               ~w(hail_mary hail_mary hail_mary sorrows_closing_prayer sign_of_cross)
    end

    test "optional closing prayers come after the closing prayer, in a fixed order" do
      steps =
        PrayerAudio.script("luminous", [1, 2, 3, 4, 5],
          closing: [:st_michael, :holy_father, :memorare]
        )

      assert Enum.take(names(steps), -7) ==
               ~w(rosary_closing_prayer our_father hail_mary glory_be memorare st_michael_prayer sign_of_cross)

      assert PrayerAudio.script("seven_sorrows", [1], closing: [:memorare])
             |> names()
             |> Enum.member?("memorare") == false
    end

    test "the plain style is the same Rosary with no meditation step" do
      plain = PrayerAudio.script("joyful", [1, 2, 3, 4, 5], style: :plain)

      assert length(plain) == 80
      refute Enum.any?(plain, &(&1.kind == :meditation))

      assert names(plain) ==
               "joyful"
               |> PrayerAudio.script([1, 2, 3, 4, 5])
               |> Enum.reject(&(&1.kind == :meditation))
               |> names()

      chaplet =
        PrayerAudio.script("seven_sorrows", Enum.to_list(1..7),
          style: :plain,
          closing: [:memorare]
        )

      assert length(chaplet) == 2 + 7 * 10 + 5
      refute "memorare" in names(chaplet)
    end

    test "decades follow the set's own mystery orders" do
      [first | _] = PrayerAudio.script("sorrowful", [3, 4]) |> Enum.filter(&(&1.decade == 0))
      assert first.name == "sorrowful_3"
    end

    test "every prayer and announcement step has a recorded clip" do
      for category <- ~w(joyful sorrowful glorious luminous seven_sorrows),
          step <-
            PrayerAudio.script(category, [1, 2, 3, 4, 5],
              closing: [:holy_father, :memorare, :st_michael]
            ),
          step.kind != :meditation do
        assert %PrayerAudio.Clip{} = PrayerAudio.clip_for_step(step), "#{category} #{step.name}"
      end
    end
  end

  describe "the Prayer Book" do
    test "its prayers come from the app's export, keyed by the book's ids" do
      book = PrayerAudio.book()

      assert length(book) > 60
      assert Enum.uniq_by(book, & &1.name) == book
      assert Enum.all?(book, &(&1.kind == :book and &1.title != nil and &1.text != ""))

      angelus = Enum.find(book, &(&1.name == "angelus"))
      assert angelus.text =~ "The Angel of the Lord declared unto Mary."
    end

    test "leaves the Rosary's own prayers to the Rosary's recordings" do
      book_ids = MapSet.new(PrayerAudio.book(), & &1.name)

      for id <- PrayerAudio.prayer_ids() do
        refute MapSet.member?(book_ids, id), "#{id} is recorded twice"
      end
    end

    test "is served only when asked for, so the Rosary's catalogue is unchanged" do
      refute Enum.any?(PrayerAudio.clips(), &(&1.kind == :book))
      assert Enum.all?(PrayerAudio.clips([:book]), &(&1.kind == :book))
      assert PrayerAudio.kinds()["book"] == :book
    end

    test "speech keeps the stanzas apart and none of the book's marks" do
      litany = Enum.find(PrayerAudio.book(), &(&1.name == "litany_loreto"))
      speech = PrayerAudio.speech_text(litany)

      assert speech =~ "Holy Mary, pray for us. Holy Mother of God, pray for us."
      assert speech =~ "\n\n"
      refute speech =~ ~r/[\[\]℣℟✠*]/
    end

    test "is stored under the voice, in its own folder" do
      clip = Enum.find(PrayerAudio.book(), &(&1.name == "sub_tuum"))

      assert PrayerAudio.s3_key(@voice, clip) =~
               ~r|^voices/female/rosary/books/sub_tuum-[0-9a-f]{10}\.mp3$|
    end
  end
end
