defmodule LumenViaeWeb.Components.AudioPlayer do
  @moduledoc """
  Reusable audio player component for meditation audio.
  """
  use Phoenix.Component

  @doc """
  Renders an audio player with play/pause controls.

  ## Examples

      <.audio_player playlist={[
        %{label: "Mystery Announcement", url: "https://..."},
        %{label: "Meditation", url: "https://..."}
      ]} />
  """
  attr :playlist, :list, default: [], doc: "Ordered list of audio tracks"

  def audio_player(assigns) do
    assigns =
      assigns
      |> assign(:encoded_playlist, encode_playlist(assigns.playlist))
      |> assign(:has_tracks, Enum.any?(assigns.playlist))

    ~H"""
    <div
      id="audio-player"
      phx-hook="AudioPlayer"
      data-playlist={@encoded_playlist}
      class="flex flex-col items-center gap-3"
    >
      <audio preload="auto"></audio>

      <p
        :if={@has_tracks}
        class="font-crimson text-xs uppercase tracking-[0.3em] text-gold-light"
        data-track-label
      >
        Tap play to begin
      </p>

      <p :if={!@has_tracks} class="font-crimson text-xs uppercase tracking-[0.3em] text-gold-light">
        Audio unavailable
      </p>

      <div class="flex items-center justify-center">
        <button
          data-audio-play
          type="button"
          class="flex items-center justify-center w-20 h-20 rounded-full bg-gold text-navy shadow-ornate disabled:opacity-30"
          disabled={!@has_tracks}
          aria-label="Play audio"
        >
          <svg xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 24 24" class="w-8 h-8 ml-1">
            <path d="M8 5v14l11-7z" />
          </svg>
        </button>

        <button
          data-audio-pause
          type="button"
          class="hidden items-center justify-center w-20 h-20 rounded-full bg-gold text-navy shadow-ornate"
          aria-label="Pause audio"
        >
          <svg xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 24 24" class="w-8 h-8">
            <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  defp encode_playlist([]), do: "[]"
  defp encode_playlist(playlist), do: Jason.encode!(playlist)
end
