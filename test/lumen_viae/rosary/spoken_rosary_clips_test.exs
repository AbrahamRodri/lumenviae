defmodule LumenViae.Rosary.SpokenRosaryClipsTest do
  @moduledoc """
  No change rewords a spoken-Rosary clip by accident.

  Every file the production voices are served, and every catalogue
  `version`, is committed in `test/support/fixtures/spoken_rosary/clips.json`
  (see `LumenViae.Test.SpokenRosaryClips`). A key that differs is a clip
  whose words, or whose voice's settings, changed: it would have to be
  recorded again, and every installed app would fetch its pack again. So
  this test is never made to pass by regenerating the fixture. Put the
  words back, or, when the change is meant, record it first (docs/SPOKEN_ROSARY.md)
  and change the fixture in the same commit, saying why.

  Synchronous, because a borrowed recording resolves its voice through the
  application environment, which this test points at production's line-up
  for its duration; ExUnit runs no other test while a synchronous one runs.
  """
  use ExUnit.Case, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Test.SpokenRosaryClips

  setup do
    put_env(:lumen_viae, :narration_voices, SpokenRosaryClips.production_voices())
  end

  defp current, do: SpokenRosaryClips.current() |> Jason.encode!() |> Jason.decode!()

  defp by_slug(%{"voices" => voices}), do: Map.new(voices, &{&1["slug"], &1})

  test "the fixture covers every production voice" do
    assert Map.keys(by_slug(current())) == Map.keys(by_slug(SpokenRosaryClips.committed()))
  end

  test "every clip is served at the key it was recorded under" do
    committed = by_slug(SpokenRosaryClips.committed())

    for {slug, %{"keys" => keys}} <- by_slug(current()) do
      pinned = committed[slug]["keys"]

      assert keys == pinned, """
      #{slug}'s spoken-Rosary keys changed. Each one below is a clip that would
      have to be recorded again:

        now:    #{Enum.join(keys -- pinned, "\n          ")}
        pinned: #{Enum.join(pinned -- keys, "\n          ")}
      """
    end
  end

  test "every catalogue version a client can be handed is unchanged" do
    committed = by_slug(SpokenRosaryClips.committed())

    for {slug, %{"versions" => versions}} <- by_slug(current()) do
      assert versions == committed[slug]["versions"],
             "#{slug}'s spoken-Rosary versions changed: every installed app would fetch its pack again"
    end
  end
end
