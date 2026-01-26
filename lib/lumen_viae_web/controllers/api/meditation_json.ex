defmodule LumenViaeWeb.API.MeditationJSON do
  alias LumenViae.Rosary.Meditation

  @doc """
  Renders a single meditation with nested mystery data.
  """
  def data(%Meditation{} = meditation) do
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

  defp mystery_data(nil), do: nil

  defp mystery_data(mystery) do
    LumenViaeWeb.API.MysteryJSON.data(mystery)
  end
end
