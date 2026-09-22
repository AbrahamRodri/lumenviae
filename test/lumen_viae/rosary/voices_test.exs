defmodule LumenViae.Rosary.VoicesTest do
  use ExUnit.Case, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Rosary.Voices
  alias LumenViae.Rosary.Voices.Voice

  test "lists the configured voices with the default first" do
    assert [%Voice{slug: "female", default: true}, %Voice{slug: "male", default: false}] =
             Voices.list()

    assert Voices.slugs() == ["female", "male"]
    assert %Voice{slug: "female"} = Voices.default()
  end

  test "puts the default first whatever order it is configured in" do
    put_env(:lumen_viae, :narration_voices, [
      %{slug: "male", name: "Male", eleven_labs_voice_id: "m"},
      %{slug: "female", name: "Female", eleven_labs_voice_id: "f", default: true}
    ])

    assert Voices.slugs() == ["female", "male"]
  end

  test "with no default configured the first voice stands in" do
    put_env(:lumen_viae, :narration_voices, [
      %{slug: "male", name: "Male", eleven_labs_voice_id: "m"},
      %{slug: "female", name: "Female", eleven_labs_voice_id: "f"}
    ])

    assert %Voice{slug: "male"} = Voices.default()
  end

  test "looks voices up by slug" do
    assert %Voice{eleven_labs_voice_id: "RTFg9niKcgGLDwa3RFlz"} = Voices.get("male")
    assert Voices.get("tenor") == nil
    assert Voices.get(nil) == nil
    assert {:ok, %Voice{slug: "female"}} = Voices.fetch("female")
    assert {:error, :unknown_voice} = Voices.fetch("tenor")
    assert Voices.valid?("male")
    refute Voices.valid?("")
  end

  test "narration keys sit under the voice prefix" do
    assert Voices.narration_key("female", "Glorious-Fulton-1.mp3") ==
             "voices/female/Glorious-Fulton-1.mp3"

    assert Voices.narration_key(Voices.get("male"), "clip.mp3") == "voices/male/clip.mp3"
  end

  test "an empty configuration has no default to hand out" do
    put_env(:lumen_viae, :narration_voices, [])

    assert Voices.list() == []
    assert_raise RuntimeError, ~r/no narration voices configured/, fn -> Voices.default() end
  end
end
