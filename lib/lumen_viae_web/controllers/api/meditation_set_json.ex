defmodule LumenViaeWeb.API.MeditationSetJSON do
  alias LumenViaeWeb.API.ArtworkJSON

  @doc """
  Renders a list of meditation sets (summary view).
  """
  def index(%{sets: sets}) do
    %{data: Enum.map(sets, &set_summary/1)}
  end

  @doc """
  Renders a single meditation set with full details.

  `audio_expires_at` describes every `audio_url` in this response at once:
  they are all signed in the same instant with the same lifetime. A client
  that stores this payload for offline prayer keeps the timestamp beside it
  and refetches (this endpoint, or `/api/meditations/:id/audio` for one
  meditation) once it has passed, instead of learning the URLs are dead
  from a 403 partway through a Rosary.
  """
  def show(%{set: set} = assigns) do
    %{data: set_detail(set, assigns[:audio_expires_at])}
  end

  defp set_summary(set) do
    %{
      id: set.id,
      name: set.name,
      category: set.category,
      description: set.description,
      labels: set.labels || []
    }
    |> Map.merge(ArtworkJSON.data(set))
  end

  defp set_detail(set, audio_expires_at) do
    %{
      id: set.id,
      name: set.name,
      category: set.category,
      description: set.description,
      labels: set.labels || [],
      audio_expires_at: encode_expiry(audio_expires_at),
      meditations: Enum.map(set.meditations, &LumenViaeWeb.API.MeditationJSON.data/1)
    }
    |> Map.merge(ArtworkJSON.data(set))
  end

  defp encode_expiry(nil), do: nil
  defp encode_expiry(%DateTime{} = at), do: DateTime.to_iso8601(at)
end
