defmodule LumenViaeWeb.Components.AudioPlayer do
  @moduledoc """
  Reusable audio player component for meditation audio.
  """
  use Phoenix.Component

  @doc """
  Renders an audio player with play/pause controls.

  ## Examples

      <.audio_player audio_url={@meditation.audio_url} />
      <.audio_player audio_url={@meditation.audio_url} size="large" />
  """
  attr :audio_url, :string, default: nil, doc: "The URL of the audio file"
  attr :size, :string, default: "normal", doc: "Size of the player: normal or large"

  def audio_player(assigns) do
    assigns = assign_button_classes(assigns)

    ~H"""
    <div
      :if={@audio_url}
      id="audio-player"
      phx-hook="AudioPlayer"
    >
      <audio preload="auto">
        <source src={@audio_url} type="audio/mpeg" />
        Your browser does not support the audio element.
      </audio>

      <div class="flex items-center justify-center">
        <button
          data-audio-play
          type="button"
          class={@button_class}
          aria-label="Play audio"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="currentColor"
            viewBox="0 0 24 24"
            class={@icon_class}
          >
            <path d="M8 5v14l11-7z" />
          </svg>
        </button>

        <button
          data-audio-pause
          type="button"
          class={["hidden", @button_class]}
          aria-label="Pause audio"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="currentColor"
            viewBox="0 0 24 24"
            class={@pause_icon_class}
          >
            <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  defp assign_button_classes(assigns) do
    {button_class, icon_class, pause_icon_class} =
      case assigns.size do
        "large" ->
          {
            "flex items-center justify-center w-20 h-20 md:w-24 md:h-24 rounded-full bg-gold hover:bg-gold-dark transition-all shadow-lg hover:shadow-xl",
            "w-10 h-10 md:w-12 md:h-12 text-navy ml-1",
            "w-10 h-10 md:w-12 md:h-12 text-navy"
          }

        _ ->
          {
            "flex items-center justify-center w-10 h-10 md:w-11 md:h-11 rounded-full bg-gold hover:bg-gold-dark transition-colors",
            "w-5 h-5 md:w-6 md:h-6 text-navy ml-0.5",
            "w-5 h-5 md:w-6 md:h-6 text-navy"
          }
      end

    assigns
    |> assign(:button_class, button_class)
    |> assign(:icon_class, icon_class)
    |> assign(:pause_icon_class, pause_icon_class)
  end
end
