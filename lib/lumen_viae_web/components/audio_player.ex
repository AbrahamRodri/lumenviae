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
  attr :label, :string, default: nil, doc: "Optional label displayed above the controls"

  def audio_player(assigns) do
    ~H"""
    <div
      :if={@audio_url}
      id="audio-player"
      phx-hook="AudioPlayer"
      data-auto-play={@auto_play}
      class="inline-flex flex-col items-center gap-3"
    >
      <audio preload="auto">
        <source src={@audio_url} type="audio/mpeg" />
        Your browser does not support the audio element.
      </audio>

      <p :if={@label} class="text-xs uppercase tracking-[0.3em] text-gold/70">
        {@label}
      </p>

      <div class="flex items-center justify-center gap-4">
        <button
          data-audio-play
          type="button"
          class="flex h-14 w-14 items-center justify-center rounded-full bg-gold text-navy shadow-lg shadow-gold/40 transition-transform duration-200 hover:scale-105"
          aria-label="Play audio"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="currentColor"
            viewBox="0 0 24 24"
            class="w-7 h-7 ml-1"
          >
            <path d="M8 5v14l11-7z" />
          </svg>
        </button>

        <button
          data-audio-pause
          type="button"
          class="hidden h-14 w-14 items-center justify-center rounded-full bg-gold text-navy shadow-lg shadow-gold/40 transition-transform duration-200 hover:scale-105"
          aria-label="Pause audio"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="currentColor"
            viewBox="0 0 24 24"
            class="w-7 h-7"
          >
            <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
          </svg>
        </button>
      </div>
    </div>
    """
  end
end
