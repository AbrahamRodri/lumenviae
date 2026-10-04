defmodule LumenViae.Rosary.RosaryContent.Verses do
  @moduledoc """
  The `verses` section of `LumenViae.Rosary.RosaryContent`: the Scriptural
  Rosary's verses as text, each mystery's in bead order, read from
  `LumenViae.Rosary.PrayerAudio.verses/0`, so they are exactly the words
  the spoken Rosary says.

  The verses are a fixed file, so the section is dated here: change the
  file, and move `@updated_at` and the pinned version in
  test/lumen_viae/rosary/rosary_content_sections_test.exs.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.PrayerAudio
  alias LumenViae.Rosary.Types

  @updated_at ~U[2026-10-04 00:00:00Z]

  @doc "When what this section serves last changed."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: @updated_at

  @impl true
  def calculate(records, _opts, _context) do
    verses = groups()

    Enum.map(records, fn _record -> verses end)
  end

  @doc "Every mystery's verses, in prayer order."
  @spec groups() :: [Types.RosaryVerses.t()]
  def groups do
    PrayerAudio.verses()
    |> Enum.chunk_by(& &1.mystery)
    |> Enum.map(fn [first | _] = clips ->
      %Types.RosaryVerses{
        key: first.mystery,
        verses:
          Enum.map(clips, fn clip ->
            %Types.RosaryVerse{bead: clip.bead, reference: clip.reference, text: clip.text}
          end)
      }
    end)
  end
end
