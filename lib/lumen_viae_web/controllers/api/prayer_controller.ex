defmodule LumenViaeWeb.API.PrayerController do
  @moduledoc """
  The four consecration chants, whose S3 keys are fixed rather than stored.
  """
  use LumenViaeWeb, :controller

  require Logger

  alias LumenViae.Rosary

  action_fallback LumenViaeWeb.API.FallbackController

  @prayers %{
    "veni_creator" => "prayers/veni_creator_spiritus.mp3",
    "ave_maris_stella" => "prayers/ave_maris_stella.mp4",
    "magnificat" => "prayers/magnificat.mp3",
    "glory_be" => "prayers/gloria_patri.mp3"
  }

  @doc """
  Returns a freshly signed URL for one chant, with the moment it expires.

  Shares `Rosary.audio_url_ttl/0` with meditation narration: two lifetimes
  for the same kind of object in the same bucket is a difference nobody
  would go looking for when one of them turned out to be too short.
  """
  def audio(conn, %{"id" => id}) do
    ttl = Rosary.audio_url_ttl()

    with {:ok, s3_key} <- fetch_key(id),
         {:ok, url} <- presign(s3_key, ttl) do
      conn
      # A presigned URL is time-limited by design. Nothing in between may
      # keep a copy to hand to somebody else after it has expired.
      |> put_resp_header("cache-control", "private, no-store")
      |> render(:audio, id: id, audio_url: url, expires_at: expiry(ttl))
    end
  end

  # Map.fetch/2 answers a bare :error, which a `with` would hand to the
  # fallback controller as-is - where it is not an {:error, _} at all and
  # matches nothing.
  defp fetch_key(id) do
    case Map.fetch(@prayers, id) do
      {:ok, s3_key} -> {:ok, s3_key}
      :error -> {:error, :not_found}
    end
  end

  defp presign(s3_key, ttl) do
    case LumenViae.Storage.S3.generate_presigned_url(s3_key, expires_in: ttl) do
      {:ok, url} ->
        {:ok, url}

      # Named rather than passed through: an S3 reason like
      # :missing_credentials matched no fallback clause and raised, and it is
      # not something a client can act on anyway.
      {:error, reason} ->
        Logger.error("Failed to sign prayer audio #{s3_key}: #{inspect(reason)}")
        {:error, :audio_unavailable}
    end
  end

  defp expiry(ttl) do
    DateTime.utc_now() |> DateTime.add(ttl, :second) |> DateTime.truncate(:second)
  end
end
