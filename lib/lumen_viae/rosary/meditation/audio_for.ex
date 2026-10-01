defmodule LumenViae.Rosary.Meditation.AudioFor do
  @moduledoc """
  Fresh narration URLs for many meditations at once: GraphQL's
  `meditationAudio`, the plural of `GET /api/meditations/:id/audio`.

  The same rules, applied to each id: without a voice the default voice is
  served (or the first that has recorded the meditation); a named voice is
  exact, a retired one meaning its successor; an archived meditation serves
  nothing. An unknown voice fails the whole request, as REST's 400 does, so
  a client with a stale voice list learns it.

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
    voice = blank_to_nil(input.arguments[:voice])

    with :ok <- check_voice(voice),
         {:ok, meditations} <- playable(ids) do
      by_id = Map.new(meditations, &{&1.id, &1})

      {:ok,
       Enum.flat_map(ids, fn id ->
         with %Meditation{} = meditation <- Map.get(by_id, id),
              {:ok, audio} <- Rosary.fetch_meditation_audio(meditation, voice) do
           [
             %MeditationNarration{
               meditation_id: id,
               voice: audio.voice.slug,
               audio: %SignedAudio{url: audio.url, expires_at: audio.expires_at}
             }
           ]
         else
           _nothing_to_play -> []
         end
       end)}
    end
  end

  defp check_voice(nil), do: :ok

  defp check_voice(slug) do
    case Voices.resolve(slug) do
      {:ok, _voice} ->
        :ok

      {:error, :unknown_voice} ->
        {:error,
         Ash.Error.Action.InvalidArgument.exception(
           field: :voice,
           message: "is not a narration voice: %{value}",
           value: slug
         )}
    end
  end

  defp playable(ids) do
    Meditation
    |> Ash.Query.filter(id in ^ids and is_nil(archived_at))
    |> Ash.Query.load(:narrations)
    |> Ash.read(authorize?: false)
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
