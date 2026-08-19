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

  @doc """
  The canonical set summary. Public because more than one endpoint renders
  it, and two shapes that drift apart would each be half of the contract.
  """
  def set_summary(set) do
    %{
      id: set.id,
      name: set.name,
      category: set.category,
      description: set.description,
      labels: set.labels || [],
      author: byline(set.author, set.derived_author),
      source: byline(set.source, set.derived_source)
    }
    |> Map.merge(ArtworkJSON.data(set))
  end

  @doc """
  The canonical set detail: the summary's fields, plus the ordered
  meditations and the moment their signed audio URLs expire.
  """
  def set_detail(set, audio_expires_at \\ nil) do
    %{
      id: set.id,
      name: set.name,
      category: set.category,
      description: set.description,
      labels: set.labels || [],
      author: byline(set.author, set.derived_author),
      source: byline(set.source, set.derived_source),
      audio_expires_at: encode_expiry(audio_expires_at),
      meditations: Enum.map(set.meditations, &LumenViaeWeb.API.MeditationJSON.data/1)
    }
    |> Map.merge(ArtworkJSON.data(set))
  end

  # The set's own byline always wins; the derivation only fills a gap, and
  # is nil unless `Rosary.resolve_attribution/1` has run over this struct.
  defp byline(nil, derived), do: derived
  defp byline("", derived), do: derived
  defp byline(explicit, _derived), do: explicit

  defp encode_expiry(nil), do: nil
  defp encode_expiry(%DateTime{} = at), do: DateTime.to_iso8601(at)
end
