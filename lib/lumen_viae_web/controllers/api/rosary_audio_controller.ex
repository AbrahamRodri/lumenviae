defmodule LumenViaeWeb.API.RosaryAudioController do
  @moduledoc """
  The spoken Rosary's recordings for one voice: the fixed prayers, the
  mystery announcements and the Scriptural Rosary's verses
  (`LumenViae.Rosary.PrayerAudio`), each with a freshly signed URL.

  One manifest rather than one request per clip, because the app downloads
  the whole pack before a Rosary begins: a network stall between the sixth
  and seventh Hail Mary is not something to discover mid-prayer.
  """
  use LumenViaeWeb, :controller

  require Logger

  alias LumenViae.Rosary
  alias LumenViae.Rosary.{PrayerAudio, Voices}

  action_fallback LumenViaeWeb.API.FallbackController

  @doc """
  `GET /api/rosary/audio[?voice=<slug>][&include=prayers,announcements,verses]`

  Without `voice` the default voice is served; an unknown slug is a 400,
  as it is for meditation narration. `include` narrows the manifest to the
  kinds named - a meditation Rosary has no use for 249 verse URLs - and
  every kind is served without it.

  `version` fingerprints every file in the voice's full catalogue, whatever
  `include` says, so a device can tell from one short field whether its
  offline pack is still current. Each entry's `file` is its name in S3 and
  changes whenever its recording would, so it doubles as the device's cache
  key.
  """
  def show(conn, params) do
    ttl = Rosary.audio_url_ttl()

    with {:ok, voice} <- fetch_voice(params["voice"]),
         {:ok, kinds} <- parse_include(params["include"]),
         {:ok, entries} <- sign(voice, PrayerAudio.clips(kinds), ttl) do
      conn
      |> put_resp_header("cache-control", "private, no-store")
      |> render(:show,
        voice: voice,
        version: PrayerAudio.version(voice, PrayerAudio.clips()),
        expires_at: expiry(ttl),
        entries: entries
      )
    end
  end

  defp fetch_voice(slug) when slug in [nil, ""], do: {:ok, Voices.default()}

  defp fetch_voice(slug) do
    case Voices.fetch(slug) do
      {:ok, voice} -> {:ok, voice}
      {:error, :unknown_voice} -> {:error, {:bad_request, "Unknown voice: #{slug}"}}
    end
  end

  defp parse_include(value) when value in [nil, ""], do: {:ok, nil}

  defp parse_include(value) do
    names = value |> String.split(",", trim: true) |> Enum.map(&String.trim/1) |> Enum.uniq()
    kinds = PrayerAudio.kinds()

    case Enum.reject(names, &Map.has_key?(kinds, &1)) do
      [] ->
        {:ok, Enum.map(names, &Map.fetch!(kinds, &1))}

      unknown ->
        {:error,
         {:bad_request,
          "Unknown include: #{Enum.join(unknown, ", ")}. " <>
            "Expected any of: #{kinds |> Map.keys() |> Enum.sort() |> Enum.join(", ")}"}}
    end
  end

  defp sign(voice, clips, ttl) do
    Enum.reduce_while(clips, {:ok, []}, fn clip, {:ok, acc} ->
      key = PrayerAudio.s3_key(voice, clip)

      case LumenViae.Storage.S3.generate_presigned_url(key, expires_in: ttl) do
        {:ok, url} ->
          entry = %{clip: clip, file: PrayerAudio.filename(voice, clip), audio_url: url}
          {:cont, {:ok, [entry | acc]}}

        {:error, reason} ->
          Logger.error("Failed to sign rosary audio #{key}: #{inspect(reason)}")
          {:halt, {:error, :audio_unavailable}}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      error -> error
    end
  end

  defp expiry(ttl) do
    DateTime.utc_now() |> DateTime.add(ttl, :second) |> DateTime.truncate(:second)
  end
end
