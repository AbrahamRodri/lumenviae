defmodule LumenViae.Rosary.NarrationsTest do
  @moduledoc """
  Narrations through the Primary Context: which voices a meditation can be
  heard in, and how the single legacy URL is chosen among them.
  """
  use LumenViae.DataCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Rosary

  setup do
    {:ok, mystery} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1})

    {:ok, meditation} =
      Rosary.create_meditation(%{
        "content" => "Content",
        "mystery_id" => mystery.id,
        "audio_url" => "clip.mp3"
      })

    %{meditation: meditation, mystery: mystery}
  end

  defp with_signing do
    put_env([
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])
  end

  test "a meditation starts with no narrations", %{meditation: meditation} do
    assert Rosary.meditation_narrations(meditation) == []
    assert Rosary.get_meditation_audio_url(meditation) == nil
    assert Rosary.fetch_meditation_audio(meditation) == :error
  end

  test "recording a voice makes it available, default voice first", %{meditation: meditation} do
    {:ok, meditation} = Rosary.record_narration(meditation, "male", "voices/male/clip.mp3")
    {:ok, meditation} = Rosary.record_narration(meditation, "female", "voices/female/clip.mp3")

    assert Enum.map(Rosary.meditation_narrations(meditation), &{&1.voice.slug, &1.s3_key}) ==
             [{"female", "voices/female/clip.mp3"}, {"male", "voices/male/clip.mp3"}]

    assert Rosary.narration_counts_by_voice() == %{"female" => 1, "male" => 1}
    assert Rosary.meditation_ids_with_narration("male") == [meditation.id]
  end

  test "recording the same voice again replaces the key", %{meditation: meditation} do
    {:ok, _} = Rosary.record_narration(meditation, "female", "voices/female/old.mp3")
    {:ok, meditation} = Rosary.record_narration(meditation, "female", "voices/female/clip.mp3")

    assert [%{s3_key: "voices/female/clip.mp3"}] = Rosary.meditation_narrations(meditation)
  end

  test "an unknown voice cannot be recorded", %{meditation: meditation} do
    assert {:error, :unknown_voice} = Rosary.record_narration(meditation, "tenor", "x.mp3")
  end

  test "a narration in a voice no longer configured is not offered", %{meditation: meditation} do
    {:ok, meditation} = Rosary.record_narration(meditation, "male", "voices/male/clip.mp3")

    put_env([
      {:lumen_viae, :narration_voices,
       [%{slug: "female", name: "F", eleven_labs_voice_id: "f", default: true}]}
    ])

    assert Rosary.meditation_narrations(meditation) == []
  end

  test "the narrations follow the meditation through the domain reads", %{
    meditation: meditation
  } do
    {:ok, _} = Rosary.record_narration(meditation, "female", "voices/female/clip.mp3")
    {:ok, set} = Rosary.create_meditation_set(%{"name" => "Set", "category" => "joyful"})
    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)

    [in_set] = Rosary.list_meditations_in_set(set.id)
    assert [%{voice: %{slug: "female"}}] = Rosary.meditation_narrations(in_set)

    assert [%{voice: %{slug: "female"}}] =
             Rosary.meditation_narrations(Rosary.get_meditation!(meditation.id))

    assert [%{voice: %{slug: "female"}}] =
             Rosary.meditation_narrations(Rosary.get_meditation(meditation.id))
  end

  test "a meditation lacking any configured voice is reported as missing one", %{
    meditation: meditation,
    mystery: mystery
  } do
    {:ok, whole} =
      Rosary.create_meditation(%{
        "content" => "W",
        "mystery_id" => mystery.id,
        "audio_url" => "w.mp3"
      })

    {:ok, _} = Rosary.record_narration(whole, "female", "voices/female/w.mp3")
    {:ok, _} = Rosary.record_narration(whole, "male", "voices/male/w.mp3")

    {:ok, silent} = Rosary.create_meditation(%{"content" => "S", "mystery_id" => mystery.id})

    {:ok, archived} =
      Rosary.create_meditation(%{
        "content" => "A",
        "mystery_id" => mystery.id,
        "audio_url" => "a.mp3"
      })

    {:ok, _} = Rosary.archive_meditation(archived)

    # The setup meditation has a filename and no recording at all.
    assert Rosary.meditation_ids_missing_a_voice() == [meditation.id]

    {:ok, _} = Rosary.record_narration(meditation, "female", "voices/female/clip.mp3")
    assert Rosary.meditation_ids_missing_a_voice() == [meditation.id]

    {:ok, _} = Rosary.record_narration(meditation, "male", "voices/male/clip.mp3")
    assert Rosary.meditation_ids_missing_a_voice() == []
    refute silent.id in Rosary.meditation_ids_missing_a_voice()
  end

  test "deleting the meditation takes its narrations with it", %{meditation: meditation} do
    {:ok, _} = Rosary.record_narration(meditation, "female", "voices/female/clip.mp3")
    {:ok, _} = Rosary.delete_meditation(meditation)

    assert Rosary.narration_counts_by_voice() == %{}
  end

  describe "signing" do
    test "the legacy URL is the default voice, or the first voice that exists", %{
      meditation: meditation
    } do
      with_signing()
      {:ok, meditation} = Rosary.record_narration(meditation, "male", "voices/male/clip.mp3")

      assert {:ok, %{voice: %{slug: "male"}, url: url, expires_at: %DateTime{}}} =
               Rosary.fetch_meditation_audio(meditation)

      assert url =~ "/voices/male/clip.mp3?"
      assert Rosary.get_meditation_audio_url(meditation) =~ "/voices/male/clip.mp3?"

      {:ok, meditation} = Rosary.record_narration(meditation, "female", "voices/female/clip.mp3")
      assert {:ok, %{voice: %{slug: "female"}}} = Rosary.fetch_meditation_audio(meditation)
    end

    test "a named voice is exact", %{meditation: meditation} do
      with_signing()
      {:ok, meditation} = Rosary.record_narration(meditation, "female", "voices/female/clip.mp3")

      assert {:ok, %{voice: %{slug: "female"}}} =
               Rosary.fetch_meditation_audio(meditation, "female")

      assert :error = Rosary.fetch_meditation_audio(meditation, "male")
      assert {:error, :unknown_voice} = Rosary.fetch_meditation_audio(meditation, "tenor")
    end

    test "signs every narration at once, default first", %{meditation: meditation} do
      with_signing()
      {:ok, meditation} = Rosary.record_narration(meditation, "male", "voices/male/clip.mp3")
      {:ok, meditation} = Rosary.record_narration(meditation, "female", "voices/female/clip.mp3")

      assert [%{voice: %{slug: "female"}, url: female}, %{voice: %{slug: "male"}, url: male}] =
               Rosary.sign_meditation_narrations(meditation)

      assert female =~ "/voices/female/clip.mp3?"
      assert male =~ "/voices/male/clip.mp3?"
    end
  end
end
