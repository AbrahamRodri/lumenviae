defmodule LumenViae.Rosary.Meditation.SignedNarrations do
  @moduledoc """
  Every narration of a meditation as a URL a client can play, default voice
  first: the GraphQL API's `narrations`. The same recordings, in the same
  order, as the REST set detail's `narrations`, from
  `LumenViae.Rosary.meditation_narrations/1`. A recording that cannot be
  signed is left out rather than handed over as a link that will fail.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Types.SignedAudio
  alias LumenViae.Rosary.Types.SignedNarration

  @impl true
  def load(_query, _opts, _context), do: [:narrations]

  @impl true
  def calculate(meditations, _opts, _context) do
    Enum.map(meditations, fn meditation ->
      meditation
      |> Rosary.meditation_narrations()
      |> Enum.flat_map(fn %{voice: voice, s3_key: s3_key} ->
        case SignedAudio.sign(s3_key) do
          {:ok, audio} -> [%SignedNarration{voice: voice.slug, audio: audio}]
          :error -> []
        end
      end)
    end)
  end
end
