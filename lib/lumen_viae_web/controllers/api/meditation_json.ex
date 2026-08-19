defmodule LumenViaeWeb.API.MeditationJSON do
  @doc """
  Renders a single meditation with nested mystery data.
  """
  def data(meditation) do
    %{
      id: meditation.id,
      title: meditation.title,
      content: meditation.content,
      author: meditation.author,
      source: meditation.source,
      audio_url: meditation.audio_url,
      mystery: mystery_data(meditation.mystery)
    }
  end

  @doc """
  Renders a freshly signed narration URL for one meditation.

  `expires_at` is ISO 8601 UTC. A client that stores `audio_url` should
  store this beside it and refetch this endpoint once it has passed, rather
  than meeting the expiry as a 403 in the middle of a decade.
  """
  def audio(%{id: id, audio: audio}) do
    %{
      data: %{
        id: id,
        audio_url: audio.url,
        expires_at: DateTime.to_iso8601(audio.expires_at)
      }
    }
  end

  defp mystery_data(nil), do: nil

  defp mystery_data(mystery) do
    LumenViaeWeb.API.MysteryJSON.data(mystery)
  end
end
