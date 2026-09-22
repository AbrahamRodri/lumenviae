defmodule LumenViaeWeb.API.MeditationJSON do
  @doc """
  Renders a single meditation with nested mystery data and its narrations.

  `narrations` carries one presigned URL per voice the meditation has been
  recorded in, default voice first. `audio_url` is the same URL as the
  first of them - the legacy single-voice field, kept so an installed app
  that predates voices goes on playing the default voice. A meditation with
  no narration has an empty `narrations` list and a null `audio_url`.

  Takes the signed narrations from the `narrations` assign the set
  controller prepares (`%{meditation_id => [%{voice:, url:}]}`), so the
  signing happens once per response rather than once per render.
  """
  def data(meditation, signed_narrations \\ []) do
    narrations = Enum.map(signed_narrations, &narration_data/1)

    %{
      id: meditation.id,
      title: meditation.title,
      content: meditation.content,
      author: meditation.author,
      source: meditation.source,
      audio_url: legacy_audio_url(narrations),
      narrations: narrations,
      mystery: mystery_data(meditation.mystery)
    }
  end

  @doc """
  Renders a freshly signed narration URL for one meditation, in one voice.

  `expires_at` is ISO 8601 UTC. A client that stores `audio_url` should
  store this beside it and refetch this endpoint once it has passed, rather
  than meeting the expiry as a 403 in the middle of a decade.
  """
  def audio(%{id: id, audio: audio}) do
    %{
      data: %{
        id: id,
        voice: audio.voice.slug,
        audio_url: audio.url,
        expires_at: DateTime.to_iso8601(audio.expires_at)
      }
    }
  end

  # Only the slug: the voice's name and description come from
  # GET /api/voices, and repeating them on every meditation of every set
  # would put a copy in each offline file that a rename could never reach.
  defp narration_data(%{voice: voice, url: url}), do: %{voice: voice.slug, audio_url: url}

  defp legacy_audio_url([]), do: nil
  defp legacy_audio_url([%{audio_url: url} | _]), do: url

  defp mystery_data(nil), do: nil

  defp mystery_data(mystery) do
    LumenViaeWeb.API.MysteryJSON.data(mystery)
  end
end
