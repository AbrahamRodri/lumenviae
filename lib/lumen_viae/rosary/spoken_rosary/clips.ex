defmodule LumenViae.Rosary.SpokenRosary.Clips do
  @moduledoc """
  Signs one kind of the spoken Rosary's clips for a voice and shapes them
  for GraphQL: prayers and the Prayer Book by prayer id, announcements by
  mystery, verses grouped by mystery in bead order. The same clips, keys
  and files as `GET /api/rosary/audio`, following a voice's borrowed
  recordings (`PrayerAudio.served_key/2`).

  A clip that cannot be signed fails the field rather than being left out:
  a pack missing one Hail Mary is not one the app can pray from, so it is
  better told to retry.
  """
  use Ash.Resource.Calculation

  require Logger

  alias LumenViae.Rosary.Errors.AudioUnavailable
  alias LumenViae.Rosary.PrayerAudio
  alias LumenViae.Rosary.Types
  alias LumenViae.Rosary.Voices

  @impl true
  def calculate(records, opts, _context) do
    kind = Keyword.fetch!(opts, :kind)

    Enum.reduce_while(records, {:ok, []}, fn record, {:ok, done} ->
      case sign(Voices.get(record.voice), PrayerAudio.clips([kind])) do
        {:ok, signed} -> {:cont, {:ok, [shape(kind, signed) | done]}}
        :error -> {:halt, {:error, AudioUnavailable.exception([])}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp sign(voice, clips) do
    Enum.reduce_while(clips, {:ok, []}, fn clip, {:ok, signed} ->
      key = PrayerAudio.served_key(voice, clip)

      case Types.SignedAudio.sign(key) do
        {:ok, audio} ->
          file = PrayerAudio.served_filename(voice, clip)
          {:cont, {:ok, [{clip, file, audio} | signed]}}

        :error ->
          Logger.error("Failed to sign rosary audio #{key}")
          {:halt, :error}
      end
    end)
    |> case do
      {:ok, signed} -> {:ok, Enum.reverse(signed)}
      :error -> :error
    end
  end

  defp shape(kind, signed) when kind in [:prayer, :book] do
    Enum.map(signed, fn {clip, file, audio} ->
      %Types.RosaryClip{id: clip.name, title: clip.title, file: file, audio: audio}
    end)
  end

  defp shape(:announcement, signed) do
    Enum.map(signed, fn {clip, file, audio} ->
      %Types.AnnouncementClip{key: clip.mystery, text: clip.text, file: file, audio: audio}
    end)
  end

  # The catalogue lists verses in mystery then bead order; chunking keeps
  # the mysteries in that order, and each group is sorted by bead anyway
  # so the app's clips[n - 1] never depends on how the catalogue is kept.
  defp shape(:verse, signed) do
    signed
    |> Enum.chunk_by(fn {clip, _file, _audio} -> clip.mystery end)
    |> Enum.map(fn [{first, _, _} | _] = group ->
      %Types.VerseGroup{
        key: first.mystery,
        clips:
          group
          |> Enum.sort_by(fn {clip, _file, _audio} -> clip.bead end)
          |> Enum.map(fn {clip, file, audio} ->
            %Types.VerseClip{
              bead: clip.bead,
              reference: clip.reference,
              file: file,
              audio: audio
            }
          end)
      }
    end)
  end
end
