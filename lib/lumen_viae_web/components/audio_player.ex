defmodule LumenViaeWeb.Components.AudioPlayer do
  @moduledoc """
  Reusable audio player component for meditation audio.
  """
  use Phoenix.Component

  @doc """
  Renders an audio player with play/pause controls and optional intro audio.

  ## Examples

      <.audio_player intro_url={@mystery.announcement_audio_url} main_url={@meditation.audio_url} />
  """
  attr :intro_url, :string, default: nil, doc: "Announcement or introduction audio"
  attr :main_url, :string, default: nil, doc: "Meditation audio"
  attr :intro_label, :string, default: "Mystery introduction", doc: "Label for the intro track"
  attr :main_label, :string, default: "Meditation audio", doc: "Label for the meditation track"
  attr :idle_label, :string, default: "Press play to begin", doc: "Label shown before playback"
  attr :complete_label, :string, default: "Meditation complete", doc: "Label shown after both tracks finish"

  def audio_player(assigns) do
    ~H"""
    <%= if @intro_url || @main_url do %>
      <div
        id="audio-player"
        phx-hook="AudioPlayer"
        data-intro-url={@intro_url}
        data-main-url={@main_url}
        data-intro-label={@intro_label}
        data-main-label={@main_label}
        data-idle-label={@idle_label}
        data-complete-label={@complete_label}
        class="flex flex-col items-center gap-4"
      >
        <audio preload="auto"></audio>

        <p data-track-label class="font-crimson text-sm text-navy/70">{@idle_label}</p>

        <div class="flex items-center justify-center gap-6">
          <button
            data-audio-play
            type="button"
            class="flex items-center justify-center w-16 h-16 rounded-full bg-gold text-navy shadow-xl transition-transform hover:scale-105"
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
            class="hidden flex items-center justify-center w-16 h-16 rounded-full bg-gold text-navy shadow-xl transition-transform hover:scale-95"
            aria-label="Pause audio"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 24 24" class="w-8 h-8">
              <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
            </svg>
          </button>
        </div>
      </div>
    <% else %>
      <div class="text-center">
        <p class="font-crimson text-sm text-navy/50">Audio is not available for this meditation yet.</p>
      </div>
    <% end %>
    """
  end
end
