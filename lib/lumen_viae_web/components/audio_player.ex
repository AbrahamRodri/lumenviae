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
  attr :audio_url, :string, default: nil, doc: "The URL of the meditation audio file"
  attr :intro_audio_url, :string, default: nil, doc: "Optional introductory announcement audio"
  attr :auto_play, :boolean, default: false, doc: "Whether to auto-play the audio"

  def audio_player(assigns) do
    ~H"""
    <div
      :if={@audio_url || @intro_audio_url}
      id="audio-player"
      phx-hook="AudioPlayer"
      data-auto-play={@auto_play}
      data-intro-src={@intro_audio_url}
      data-main-src={@audio_url}
      class="rounded-3xl border border-gold/30 bg-white/5 px-4 py-4 shadow-soft"
    >
      <audio preload="auto">
        <source src="" type="audio/mpeg" />
        Your browser does not support the audio element.
      </audio>

      <div class="flex items-center justify-between gap-4">
        <div class="relative">
          <button
            data-audio-play
            type="button"
            class="flex items-center justify-center w-16 h-16 rounded-full bg-gold text-navy shadow-lg transition-transform duration-200 hover:scale-105"
            aria-label="Play audio"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="currentColor"
              viewBox="0 0 24 24"
              class="w-8 h-8 ml-1"
            >
              <path d="M8 5v14l11-7z" />
            </svg>
          </button>
          <button
            data-audio-pause
            type="button"
            class="hidden absolute inset-0 flex items-center justify-center w-16 h-16 rounded-full bg-gold text-navy shadow-lg transition-transform duration-200 hover:scale-105"
            aria-label="Pause audio"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="currentColor"
              viewBox="0 0 24 24"
              class="w-8 h-8"
            >
              <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
            </svg>
          </button>
        </div>

        <div class="flex-1 text-center">
          <p class="font-crimson text-[0.65rem] uppercase tracking-[0.45em] text-gold/80" data-phase-label-intro>
            Announcement
          </p>
          <p class="font-crimson text-[0.65rem] uppercase tracking-[0.45em] text-gold/80 hidden" data-phase-label-main>
            Meditation
          </p>
          <p class="font-crimson text-sm text-cream/80 mt-2">
            Allow the audio to lead the prayer at a gentle pace.
          </p>
        </div>

        <div class="w-16 h-16"></div>
      </div>
    </div>
    """
  end
end
