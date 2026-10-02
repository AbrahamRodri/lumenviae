defmodule LumenViae.Rosary.RetiredVoicesTest do
  @moduledoc """
  A voice retired from the pickers (`hidden: true`) and a voice that
  borrows another's spoken-Rosary recordings (`rosary_audio_from`): the
  line-up production moved to when Frederick replaced Marc Aurele.
  """
  use LumenViae.DataCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Rosary
  alias LumenViae.Rosary.{PrayerAudio, Voices}
  alias LumenViae.Rosary.Voices.Voice

  @voices [
    %{
      slug: "frederick",
      name: "Male",
      eleven_labs_voice_id: "fr",
      model_id: "eleven_v4",
      rosary_audio_from: %{prayer: "male", announcement: "male", verse: "male", book: "female"},
      default: true
    },
    %{slug: "female", name: "Female", eleven_labs_voice_id: "f", model_id: "eleven_v3"},
    %{
      slug: "male",
      name: "Male (original)",
      eleven_labs_voice_id: "m",
      model_id: "eleven_multilingual_v2",
      hidden: true,
      replaced_by: "frederick"
    }
  ]

  setup do
    put_env([
      {:lumen_viae, :narration_voices, @voices},
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    {:ok, mystery} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1},
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(
        %{
          "content" => "Content",
          "mystery_id" => mystery.id,
          "audio_url" => "clip.mp3"
        },
        actor: admin()
      )

    %{meditation: meditation}
  end

  describe "the line-up" do
    test "a hidden voice is not offered, but still resolves for tooling" do
      assert Voices.slugs() == ["frederick", "female"]
      assert Enum.map(Voices.all(), & &1.slug) == ["frederick", "female", "male"]
      assert %Voice{slug: "frederick"} = Voices.default()

      assert %Voice{slug: "male", hidden: true} = Voices.get("male")
      assert {:ok, %Voice{slug: "male"}} = Voices.fetch("male")
      assert Voices.valid?("male")
    end

    test "a client naming a hidden voice is served its successor" do
      assert {:ok, %Voice{slug: "frederick"}} = Voices.resolve("male")
      assert {:ok, %Voice{slug: "female"}} = Voices.resolve("female")
      assert {:error, :unknown_voice} = Voices.resolve("tenor")
      assert {:error, :unknown_voice} = Voices.resolve(nil)
    end

    test "a hidden voice without a successor is served the default" do
      put_env([
        {:lumen_viae, :narration_voices,
         [
           %{slug: "female", name: "F", eleven_labs_voice_id: "f", default: true},
           %{slug: "old", name: "Old", eleven_labs_voice_id: "o", hidden: true}
         ]}
      ])

      assert {:ok, %Voice{slug: "female"}} = Voices.resolve("old")
    end

    test "a hidden voice is never the default, even when marked so" do
      put_env([
        {:lumen_viae, :narration_voices,
         [
           %{slug: "old", name: "Old", eleven_labs_voice_id: "o", hidden: true, default: true},
           %{slug: "female", name: "F", eleven_labs_voice_id: "f"}
         ]}
      ])

      assert %Voice{slug: "female"} = Voices.default()
    end
  end

  describe "meditation narration" do
    test "the retired voice's recording is kept but not offered", %{meditation: meditation} do
      {:ok, meditation} =
        Rosary.record_narration(meditation, "male", "voices/male/clip.mp3", actor: admin())

      assert Rosary.meditation_narrations(meditation) == []

      {:ok, meditation} =
        Rosary.record_narration(meditation, "frederick", "voices/frederick/clip.mp3",
          actor: admin()
        )

      assert [%{voice: %{slug: "frederick"}}] = Rosary.meditation_narrations(meditation)
    end

    test "asking for the retired voice plays its successor", %{meditation: meditation} do
      {:ok, meditation} =
        Rosary.record_narration(meditation, "male", "voices/male/clip.mp3", actor: admin())

      {:ok, meditation} =
        Rosary.record_narration(meditation, "frederick", "voices/frederick/clip.mp3",
          actor: admin()
        )

      assert {:ok, %{voice: %{slug: "frederick"}, url: url}} =
               Rosary.fetch_meditation_audio(meditation, "male")

      assert url =~ "voices/frederick/clip.mp3"
      assert Rosary.get_meditation_audio_url(meditation) =~ "voices/frederick/clip.mp3"
    end

    test "the missing-voice check asks only for the offered voices", %{meditation: meditation} do
      {:ok, meditation} =
        Rosary.record_narration(meditation, "frederick", "voices/frederick/clip.mp3",
          actor: admin()
        )

      assert Rosary.meditation_ids_missing_a_voice(actor: admin()) == [meditation.id]

      {:ok, _} =
        Rosary.record_narration(meditation, "female", "voices/female/clip.mp3", actor: admin())

      assert Rosary.meditation_ids_missing_a_voice(actor: admin()) == []
    end
  end

  describe "borrowed spoken-Rosary recordings" do
    test "each kind is served from the voice named for it" do
      frederick = Voices.get("frederick")
      male = Voices.get("male")
      female = Voices.get("female")
      [prayer | _] = PrayerAudio.clips([:prayer])
      [verse | _] = PrayerAudio.clips([:verse])
      [book | _] = PrayerAudio.clips([:book])

      assert PrayerAudio.served_voice(frederick, prayer) == male
      assert PrayerAudio.served_key(frederick, prayer) == PrayerAudio.s3_key(male, prayer)
      assert PrayerAudio.served_filename(frederick, verse) == PrayerAudio.filename(male, verse)
      assert PrayerAudio.served_key(frederick, book) == PrayerAudio.s3_key(female, book)

      # Generation still writes a voice's own keys
      assert PrayerAudio.s3_key(frederick, prayer) =~ "voices/frederick/rosary/prayers/"
    end

    test "a voice that borrows nothing is served its own recordings" do
      female = Voices.get("female")

      for clip <- PrayerAudio.clips() ++ PrayerAudio.clips([:book]) do
        assert PrayerAudio.served_key(female, clip) == PrayerAudio.s3_key(female, clip)
      end
    end

    test "the version fingerprints what is served, so dropping a borrow changes it" do
      clips = PrayerAudio.clips()
      frederick = Voices.get("frederick")
      borrowing = PrayerAudio.version(frederick, clips)

      assert PrayerAudio.version(%{frederick | rosary_audio_from: %{}}, clips) != borrowing
    end
  end
end
