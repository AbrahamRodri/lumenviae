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
  attr :theme, :atom,
    default: :default,
    values: [:default, :translucent],
    doc: "Visual style variant for the player"

  def audio_player(assigns) do
    ~H"""
    <div
      :if={@audio_url}
      id="audio-player"
      phx-hook="AudioPlayer"
      data-auto-play={@auto_play}
      class={container_classes(@theme)}
    >
      <audio preload="auto">
        <source src={@audio_url} type="audio/mpeg" />
        Your browser does not support the audio element.
      </audio>

      <div class="flex items-center justify-center gap-4">
        <button
          data-audio-play
          type="button"
          class={play_button_classes(@theme)}
          aria-label="Play audio"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="currentColor"
            viewBox="0 0 24 24"
            class="w-8 h-8 text-navy ml-1"
          >
            <path d="M8 5v14l11-7z" />
          </svg>
        </button>

        <button
          data-audio-pause
          type="button"
          class={pause_button_classes(@theme)}
          aria-label="Pause audio"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="currentColor"
            viewBox="0 0 24 24"
            class="w-8 h-8 text-navy"
          >
            <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  defp container_classes(:translucent),
    do:
      "mt-6 mb-4 px-4 py-3 rounded-2xl border border-gold/40 bg-white/10 backdrop-blur-sm shadow-soft"

  defp container_classes(_), do: "mt-6 mb-4"

  defp play_button_classes(:translucent),
    do:
      "flex items-center justify-center w-14 h-14 rounded-full bg-gold/90 hover:bg-gold transition-colors shadow-soft"

  defp play_button_classes(_),
    do:
      "flex items-center justify-center w-16 h-16 rounded-full bg-gold hover:bg-gold-dark transition-colors shadow-lg"

  defp pause_button_classes(:translucent),
    do:
      "hidden flex items-center justify-center w-14 h-14 rounded-full bg-gold/90 hover:bg-gold transition-colors shadow-soft"

  defp pause_button_classes(_),
    do:
      "hidden flex items-center justify-center w-16 h-16 rounded-full bg-gold hover:bg-gold-dark transition-colors shadow-lg"
end
