defmodule LumenViae.Rosary.Meditation.SignedNarrations do
  @moduledoc """
  Every narration of a meditation as a URL a client can play, default voice
  first: the GraphQL API's `narrations`. The same recordings, in the same
  order, as the REST set detail's `narrations`, from
  `LumenViae.Rosary.meditation_narrations/1`.

  All or nothing. When a recording exists but cannot be signed (the
  storage credentials are missing or broken), the answer is null, never a
  shorter list: a list missing one voice reads as "that voice was never
  recorded", and a player would quietly switch narrator. So `[]` always
  means nothing is recorded, and null means try again later. The failure
  is logged.
  """
  use Ash.Resource.Calculation

  require Logger

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Types.SignedAudio
  alias LumenViae.Rosary.Types.SignedNarration

  # The fields by name: a calculation's dependency is loaded with only the
  # primary key selected unless it asks for more, and a narration without
  # its voice and key is no recording at all.
  @impl true
  def load(_query, _opts, _context), do: [narrations: [:voice, :s3_key]]

  @impl true
  def calculate(meditations, _opts, _context) do
    Enum.map(meditations, &sign_all/1)
  end

  defp sign_all(meditation) do
    meditation
    |> Rosary.meditation_narrations()
    |> Enum.reduce_while([], fn %{voice: voice, s3_key: s3_key}, signed ->
      case SignedAudio.sign(s3_key) do
        {:ok, audio} ->
          {:cont, [%SignedNarration{voice: voice.slug, audio: audio} | signed]}

        :error ->
          Logger.error("Failed to sign narration #{s3_key} of meditation #{meditation.id}")
          {:halt, :error}
      end
    end)
    |> case do
      :error -> nil
      signed -> Enum.reverse(signed)
    end
  end
end
