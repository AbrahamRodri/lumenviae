defmodule LumenViae.Rosary.SpokenRosary.ForVoice do
  @moduledoc """
  Answers a `LumenViae.Rosary.SpokenRosary` read with one record for the
  voice the client will actually hear: the `voice` argument when the read
  takes one, and the default voice otherwise. A slug that names no voice is
  an `invalid_argument` error on `voice` - REST's 400, which is what sends
  the app back to the default voice.
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

      {:error, :unknown_voice} ->
        Ash.Query.add_error(
          query,
          Ash.Error.Query.InvalidArgument.exception(
            field: :voice,
            message: "is not a narration voice: %{value}",
            value: slug
          )
        )
    end
  end

  defp resolve(slug) when slug in [nil, ""], do: {:ok, Voices.default()}
  defp resolve(slug), do: Voices.resolve(slug)
end
