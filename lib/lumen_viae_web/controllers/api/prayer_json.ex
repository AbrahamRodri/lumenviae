defmodule LumenViaeWeb.API.PrayerJSON do
  def audio(%{id: id, audio_url: audio_url}) do
    %{data: %{id: id, audio_url: audio_url}}
  end
end
