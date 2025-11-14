defmodule LumenViaeWeb.Components.AudioPlayer do
  @moduledoc """
  Reusable audio player component for meditation audio.
  """
  use Phoenix.Component

  @doc """
  Renders an audio player with play/pause controls.

  ## Examples

      <.audio_player audio_url={@meditation.audio_url} auto_play={true} />

      <.audio_player audio_url={@meditation.audio_url} auto_play={false} />
  """
  attr :audio_url, :string, default: nil, doc: "The URL of the audio file"
  attr :auto_play, :boolean, default: false, doc: "Whether to auto-play the audio"

  def audio_player(assigns) do
    ~H"""
    <div
      :if={@audio_url}
      id="audio-player"
      phx-hook="AudioPlayer"
      data-auto-play={@auto_play}
    >
      <audio preload="auto">
        <source src={@audio_url} type="audio/mpeg" />
        Your browser does not support the audio element.
      </audio>

      <div class="flex items-center justify-center">
        <button
          data-audio-play
          type="button"
          class="flex items-center justify-center w-10 h-10 md:w-11 md:h-11 rounded-full bg-gold hover:bg-gold-dark transition-colors"
          aria-label="Play audio"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="currentColor"
            viewBox="0 0 24 24"
            class="w-5 h-5 md:w-6 md:h-6 text-navy ml-0.5"
          >
            <path d="M8 5v14l11-7z" />
          </svg>
        </button>

        <button
          data-audio-pause
          type="button"
          class="hidden flex items-center justify-center w-10 h-10 md:w-11 md:h-11 rounded-full bg-gold hover:bg-gold-dark transition-colors"
          aria-label="Pause audio"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="currentColor"
            viewBox="0 0 24 24"
            class="w-5 h-5 md:w-6 md:h-6 text-navy"
          >
            <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
          </svg>
        </button>
      </div>
    </div>
    """
  end
end
