defmodule LumenViae.Rosary.Meditation.AudioFor do
  @moduledoc """
  Fresh narration URLs for many meditations at once: GraphQL's
  `meditationAudio`, the plural of `GET /api/meditations/:id/audio`.

  The voice is a preference, as everywhere in the GraphQL API: each
  meditation is answered in the preferred voice when it has recorded it (a
  retired voice meaning its successor), and otherwise in the default voice,
  or the first that has. An unknown slug is no preference. Every answer
  names the voice it is in, so a client always knows what it got - where
  REST answers an unknown voice with a 400 and a missing one with a 404.
  An archived meditation serves nothing.

  Plural because a device resuming an offline download re-signs a whole set
  without refetching its text. An id with nothing to play is left out of
  the answer rather than failing the batch, so one withdrawn meditation
  does not cost the rest. Answers follow the order of the ids asked for.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Meditation
  alias LumenViae.Rosary.Types.MeditationNarration
  alias LumenViae.Rosary.Types.SignedAudio
  alias LumenViae.Rosary.Voices

  @impl true
  def run(input, _opts, _context) do
    ids = Enum.uniq(input.arguments.meditation_ids)
    preferred = preferred_slug(input.arguments[:voice])

    with {:ok, meditations} <- playable(ids) do
      by_id = Map.new(meditations, &{&1.id, &1})

      {:ok, Enum.flat_map(ids, &answer(Map.get(by_id, &1), &1, preferred))}
    end
  end

  defp answer(nil, _id, _preferred), do: []

  defp answer(meditation, id, preferred) do
    narrations = Rosary.meditation_narrations(meditation)

    with %{voice: voice, s3_key: s3_key} <-
           Enum.find(narrations, &(&1.voice.slug == preferred)) || List.first(narrations),
         {:ok, audio} <- SignedAudio.sign(s3_key) do
      [%MeditationNarration{meditation_id: id, voice: voice.slug, audio: audio}]
    else
      _nothing_to_play -> []
    end
  end

  defp preferred_slug(slug) when slug in [nil, ""], do: nil

  defp preferred_slug(slug) do
    case Voices.resolve(slug) do
      {:ok, voice} -> voice.slug
      {:error, :unknown_voice} -> nil
    end
  end

  defp playable(ids) do
    Meditation
    |> Ash.Query.filter(id in ^ids and is_nil(archived_at))
    |> Ash.Query.load(narrations: [:voice, :s3_key])
    |> Ash.read(authorize?: false)
  end
end
