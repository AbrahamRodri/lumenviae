defmodule LumenViaeWeb.API.MeditationSetJSON do
  alias LumenViae.Rosary
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
    %{
      data:
        set
        |> set_detail(assigns[:audio_expires_at], assigns[:narrations] || %{})
        |> put_translations(set)
        |> put_set_translation(set)
    }
  end

  # Only a set read with `?lang=` has its translations loaded; any other
  # renders exactly as before, with no `translations` key.
  defp put_translations(data, %{translations: translations}) when is_list(translations) do
    Map.put(data, :translations, Enum.map(translations, &translation/1))
  end

  defp put_translations(data, _set), do: data

  # Likewise `set_translation`: only with `?lang=`, null when the set has
  # no Spanish of its own; any other read has no such key.
  defp put_set_translation(data, %{set_translation: %Ash.NotLoaded{}}), do: data

  defp put_set_translation(data, %{set_translation: nil}),
    do: Map.put(data, :set_translation, nil)

  defp put_set_translation(data, %{set_translation: spanish}) when is_map(spanish) do
    Map.put(
      data,
      :set_translation,
      %{
        name: spanish.name,
        author: spanish.author,
        description: spanish.description,
        source: spanish.source,
        image_alt: spanish.artwork_alt
      }
      |> then(
        &if(Map.get(spanish, :ai_translated) == true,
          do: Map.put(&1, :ai_translated, true),
          else: &1
        )
      )
    )
  end

  defp put_set_translation(data, _set), do: data

  defp translation(translation) do
    %{id: translation.id, title: translation.title, content: translation.content}
    |> then(
      &if(Map.get(translation, :ai_translated) == true,
        do: Map.put(&1, :ai_translated, true),
        else: &1
      )
    )
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
    |> Map.merge(ArtworkJSON.data(Rosary.artwork_record(set)))
  end

  @doc """
  The canonical set detail: the summary's fields, plus the ordered
  meditations and the moment their signed audio URLs expire.

  `narrations` maps each meditation id to its signed narrations
  (`[%{voice:, url:}]`, default voice first); a meditation absent from it
  renders with none.
  """
  def set_detail(set, audio_expires_at \\ nil, narrations \\ %{}) do
    %{
      id: set.id,
      name: set.name,
      category: set.category,
      description: set.description,
      labels: set.labels || [],
      author: byline(set.author, set.derived_author),
      source: byline(set.source, set.derived_source),
      audio_expires_at: encode_expiry(audio_expires_at),
      meditations:
        Enum.map(
          set.meditations,
          &LumenViaeWeb.API.MeditationJSON.data(&1, Map.get(narrations, &1.id, []))
        )
    }
    |> Map.merge(ArtworkJSON.data(Rosary.artwork_record(set)))
  end

  # The set's own byline always wins; the derivation only fills a gap, and
  # is nil unless `Rosary.resolve_attribution/1` has run over this struct.
  defp byline(nil, derived), do: derived
  defp byline("", derived), do: derived
  defp byline(explicit, _derived), do: explicit

  defp encode_expiry(nil), do: nil
  defp encode_expiry(%DateTime{} = at), do: DateTime.to_iso8601(at)
end
