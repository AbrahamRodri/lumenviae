defmodule LumenViae.Curation.NarrationRelocation do
  @moduledoc """
  One-time move of the original narrations into the voice layout.

  Before voices, a meditation's `audio_url` was the S3 key of its one
  recording, a root-level object such as `Glorious-Fulton-1.mp3`. Every
  such recording was made with the voice now configured as `male`, and the
  narrations table (backfilled by the migration that created it) expects
  each at `voices/male/<filename>`. This copies them there, server side,
  one meditation at a time, and leaves the originals for a later manual
  clean-up once the new keys have been verified to play.

  Idempotent: a destination that already exists is skipped, so a run cut
  short can simply be repeated. A source that no longer exists is reported
  as a warning - the meditation's narration was already broken - rather
  than failing the run.

  Used by `LumenViae.Release.copy_narration_to_voice_prefix/0`.

  ## Options

    * `:progress` - a 1-arity function receiving `{:started, total}` and
      `{:item_finished, index, total, result}` events
  """

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Voices
  alias LumenViae.Storage.S3

  @original_voice "male"

  def run(opts \\ []) do
    meditations =
      Rosary.list_meditations()
      |> Enum.reject(&(&1.audio_url in [nil, ""]))
      |> Enum.sort_by(& &1.id)

    total = length(meditations)
    notify(opts, {:started, total})

    meditations
    |> Enum.with_index(1)
    |> Enum.map(fn {meditation, index} ->
      result = relocate(meditation)
      notify(opts, {:item_finished, index, total, result})
      result
    end)
  end

  defp relocate(%{id: id, audio_url: filename}) do
    source = filename
    destination = Voices.narration_key(@original_voice, filename)

    case S3.audio_exists?(destination) do
      {:ok, true} ->
        {:ok, "Kept #{destination} for meditation #{id} (already in place)"}

      {:ok, false} ->
        case S3.copy_audio(source, destination) do
          {:ok, ^destination} ->
            {:ok, "Copied #{source} to #{destination} for meditation #{id}"}

          {:error, :not_found} ->
            {:warning, "No object at #{source} for meditation #{id}; nothing to copy"}

          {:error, reason} ->
            {:error, "Failed to copy #{source} for meditation #{id}: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Could not check #{destination} for meditation #{id}: #{inspect(reason)}"}
    end
  end

  defp notify(opts, event) do
    case opts[:progress] do
      fun when is_function(fun, 1) -> fun.(event)
      _ -> :ok
    end
  end
end
