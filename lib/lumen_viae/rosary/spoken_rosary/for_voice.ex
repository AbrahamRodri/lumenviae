defmodule LumenViae.Rosary.SpokenRosary.ForVoice do
  @moduledoc """
  Answers a `LumenViae.Rosary.SpokenRosary` read with one record for the
  voice the client will actually hear: the voice asked for (a retired one
  meaning its successor), and the default voice when none is asked for or
  the slug names no voice. A voice is a preference, and the answer's
  `voice` says which one was served - where REST answers an unknown slug
  with a 400 and the app has to ask again.
  """
  use Ash.Resource.Preparation

  alias LumenViae.Rosary.PrayerAudio
  alias LumenViae.Rosary.SpokenRosary
  alias LumenViae.Rosary.Types.SignedAudio
  alias LumenViae.Rosary.Voices

  @impl true
  def prepare(query, _opts, _context) do
    slug = Ash.Query.get_argument(query, :voice)

    case resolve(slug) do
      {:ok, voice} ->
        record =
          struct(SpokenRosary, %{
            voice: voice.slug,
            version: PrayerAudio.version(voice, PrayerAudio.clips()),
            # Taken before any clip is signed, so it is never later than
            # the expiry of a URL in the same response.
            expires_at: SignedAudio.expiry()
          })

        Ash.DataLayer.Simple.set_data(query, [record])
    end
  end

  defp resolve(slug) when slug in [nil, ""], do: {:ok, Voices.default()}

  defp resolve(slug) do
    case Voices.resolve(slug) do
      {:ok, voice} -> {:ok, voice}
      {:error, :unknown_voice} -> {:ok, Voices.default()}
    end
  end
end
