defmodule LumenViaeWeb.API.PrayerJSON do
  @doc """
  Renders a freshly signed chant URL.

  `expires_at` is ISO 8601 UTC and is additive: the shipped
  `PrayerAudioResponse` decodes only `id` and `audio_url`, so installed
  builds are unaffected, and a client that stores the URL can now tell when
  it has gone stale instead of meeting the expiry as a 403.
  """
  def audio(%{id: id, audio_url: audio_url} = assigns) do
    %{
      data: %{
        id: id,
        audio_url: audio_url,
        expires_at: DateTime.to_iso8601(assigns.expires_at)
      }
    }
  end
end
