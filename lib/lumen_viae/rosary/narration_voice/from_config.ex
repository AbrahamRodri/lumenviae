defmodule LumenViae.Rosary.NarrationVoice.FromConfig do
  @moduledoc """
  Answers a `LumenViae.Rosary.NarrationVoice` read from the configured
  voices, in config order. A retired voice whose config names no
  successor is answered by the default voice, as `Voices.resolve/1` does,
  so `replaced_by` is never null for a retired voice.
  """
  use Ash.Resource.Preparation

  alias LumenViae.Rosary.NarrationVoice
  alias LumenViae.Rosary.Voices

  @impl true
  def prepare(query, _opts, _context) do
    records =
      Voices.all()
      |> Enum.with_index()
      |> Enum.map(fn {voice, position} ->
        struct(NarrationVoice, %{
          slug: voice.slug,
          name: voice.name,
          description: voice.description,
          default: voice.default,
          retired: voice.hidden,
          replaced_by: successor(voice),
          position: position
        })
      end)

    Ash.DataLayer.Simple.set_data(query, records)
  end

  defp successor(%{hidden: false}), do: nil

  defp successor(voice) do
    {:ok, served} = Voices.resolve(voice.slug)
    served.slug
  end
end
