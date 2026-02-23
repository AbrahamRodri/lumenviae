defmodule LumenViaeWeb.API.PrayerController do
  use LumenViaeWeb, :controller

  action_fallback LumenViaeWeb.API.FallbackController

  @prayers %{
    "veni_creator" => "prayers/veni_creator_spiritus.mp3",
    "ave_maris_stella" => "prayers/ave_maris_stella.mp4",
    "magnificat" => "prayers/magnificat.mp3",
    "glory_be" => "prayers/gloria_patri.mp3"
  }

  def audio(conn, %{"id" => id}) do
    case Map.fetch(@prayers, id) do
      {:ok, s3_key} ->
        case LumenViae.Storage.S3.generate_presigned_url(s3_key, expires_in: 86_400) do
          {:ok, url} -> render(conn, :audio, id: id, audio_url: url)
          {:error, reason} -> {:error, reason}
        end

      :error ->
        {:error, :not_found}
    end
  end
end
