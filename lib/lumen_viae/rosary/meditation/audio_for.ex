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
  without refetching its text. An id with nothing to play - missing,
  archived, or never recorded - is left out of the answer rather than
  failing the batch, so one withdrawn meditation does not cost the rest.
  Answers follow the order of the ids asked for.

  A recording that cannot be signed is different: it fails the whole field
  with `audio_unavailable`. Signing fails for every recording at once (the
  storage credentials are missing or broken), and leaving those ids out
  would read as "withdrawn", so a player would skip every meditation and an
  offline resume would save a set as having no recordings.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  require Logger

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Errors.AudioUnavailable
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

      Enum.reduce_while(ids, {:ok, []}, fn id, {:ok, answers} ->
        case answer(Map.get(by_id, id), id, preferred) do
          {:ok, answer} -> {:cont, {:ok, [answer | answers]}}
          :nothing_to_play -> {:cont, {:ok, answers}}
          :unsignable -> {:halt, {:error, AudioUnavailable.exception([])}}
        end
      end)
      |> case do
        {:ok, answers} -> {:ok, Enum.reverse(answers)}
        error -> error
      end
    end
  end

  defp answer(nil, _id, _preferred), do: :nothing_to_play

  defp answer(meditation, id, preferred) do
    narrations = Rosary.meditation_narrations(meditation)

    case Enum.find(narrations, &(&1.voice.slug == preferred)) || List.first(narrations) do
      nil ->
        :nothing_to_play

      %{voice: voice, s3_key: s3_key} ->
        case SignedAudio.sign(s3_key) do
          {:ok, audio} ->
            {:ok, %MeditationNarration{meditation_id: id, voice: voice.slug, audio: audio}}

          :error ->
            Logger.error("Failed to sign narration #{s3_key} of meditation #{id}")
            :unsignable
        end
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
