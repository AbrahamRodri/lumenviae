defmodule LumenViae.Rosary.Meditation.PreferredNarration do
  @moduledoc """
  The one narration a listener who prefers a voice should hear: that voice
  when it has recorded the meditation (a retired voice meaning its
  successor), and otherwise the default voice's, or the first voice's that
  has. Null only when nothing is recorded or nothing can be signed.

  A preference, not a demand, so an unknown slug falls back like an absent
  one instead of failing the query: the field exists so a client does not
  have to carry these rules itself, and the voice it actually got is in
  the answer.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Types.SignedAudio
  alias LumenViae.Rosary.Types.SignedNarration
  alias LumenViae.Rosary.Voices

  # The fields by name: a calculation's dependency is loaded with only the
  # primary key selected unless it asks for more, and a narration without
  # its voice and key is no recording at all.
  @impl true
  def load(_query, _opts, _context), do: [narrations: [:voice, :s3_key]]

  @impl true
  def calculate(meditations, _opts, context) do
    preferred = preferred_slug(context.arguments[:preferring])

    Enum.map(meditations, fn meditation ->
      narrations = Rosary.meditation_narrations(meditation)

      chosen =
        Enum.find(narrations, &(&1.voice.slug == preferred)) || List.first(narrations)

      with %{voice: voice, s3_key: s3_key} <- chosen,
           {:ok, audio} <- SignedAudio.sign(s3_key) do
        %SignedNarration{voice: voice.slug, audio: audio}
      else
        _nothing -> nil
      end
    end)
  end

  defp preferred_slug(slug) when is_binary(slug) do
    case Voices.resolve(slug) do
      {:ok, voice} -> voice.slug
      {:error, :unknown_voice} -> nil
    end
  end

  defp preferred_slug(_none), do: nil
end
