defmodule LumenViae.Test.SpokenRosaryClips do
  @moduledoc """
  Every spoken-Rosary file the production voices are served, and every
  catalogue `version` a client can be handed, as the code computes them
  now and as `test/support/fixtures/spoken_rosary/clips.json` committed
  them.

  A file name hashes the words a narrator is sent and the voice's
  synthesis settings (`LumenViae.Rosary.PrayerAudio.filename/2`), so a key
  that moves is a recording to pay for, and a `version` that moves makes
  every installed app fetch its pack again. The fixture is not regenerated
  to make a test pass: a difference is a reworded clip, found before it
  ships. See `LumenViae.Rosary.SpokenRosaryClipsTest`.

  The voices are production's, read from `config/config.exs` (the suite
  runs on voices of its own, `config/test.exs`). A borrowed recording is
  resolved through the application environment (`Voices.get/1`), so
  `current/0` expects that line-up to be in it.
  """

  alias LumenViae.Rosary.PrayerAudio
  alias LumenViae.Rosary.Voices

  @fixture "test/support/fixtures/spoken_rosary/clips.json"

  @kinds [:prayer, :announcement, :verse, :book]

  @doc "The fixture's path, from the project root."
  def fixture, do: @fixture

  @doc "The production voice line-up, as `config/config.exs` declares it."
  def production_voices do
    "config/config.exs"
    |> Config.Reader.read!(env: :prod, target: :host)
    |> get_in([:lumen_viae, :narration_voices])
  end

  @doc """
  The combinations of kinds a `version` is pinned for: the manifest's own
  (`"default"`, `PrayerAudio.clips/0`) and every non-empty subset of the
  four kinds, each listed prayer, announcement, verse, book.
  """
  def combinations do
    subsets =
      for mask <- 1..(2 ** length(@kinds) - 1) do
        for {kind, bit} <- Enum.with_index(@kinds), Bitwise.band(mask, 2 ** bit) != 0, do: kind
      end

    [{"default", nil} | Enum.map(subsets, &{Enum.join(&1, ","), &1})]
  end

  @doc """
  What the running code serves, in the fixture's shape: per voice (every
  configured voice, hidden ones included), the served key of every clip of
  every kind and the version of every combination.
  """
  def current do
    %{
      "voices" =>
        for voice <- Voices.all() do
          %{
            "slug" => voice.slug,
            "keys" => Enum.map(PrayerAudio.clips(@kinds), &PrayerAudio.served_key(voice, &1)),
            "versions" =>
              Jason.OrderedObject.new(
                for {name, kinds} <- combinations(),
                    do: {name, PrayerAudio.version(voice, PrayerAudio.clips(kinds))}
              )
          }
        end
    }
  end

  @doc "The committed fixture, decoded."
  def committed, do: @fixture |> File.read!() |> Jason.decode!()
end
