defmodule LumenViae.Rosary.Meditation.NarratedVoices do
  @moduledoc """
  The voices that have recorded a meditation, default first, as slugs,
  signing nothing: GraphQL's `narratedVoices`.

  What lets a client read a null `narration` or `narrations` correctly:
  null beside an empty list means nothing is recorded; null beside a
  non-empty one means the recordings exist and could not be signed just
  now. And a shelf can say "has audio" without a URL signed for it.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary

  @impl true
  def load(_query, _opts, _context), do: [narrations: [:voice, :s3_key]]

  @impl true
  def calculate(meditations, _opts, _context) do
    Enum.map(meditations, fn meditation ->
      meditation |> Rosary.meditation_narrations() |> Enum.map(& &1.voice.slug)
    end)
  end
end
