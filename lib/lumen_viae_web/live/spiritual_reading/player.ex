defmodule LumenViaeWeb.Live.SpiritualReading.Player do
  @moduledoc """
  A book's LibriVox recording on its pages, as the iOS app's
  `LibraryPlayerViews` set it: the mini player at the foot of the screen
  (the reading's title, which opens the player, back fifteen seconds, play
  and pause), and the player itself (`LibraryPlayerSheet`, opened in place
  above the mini player): "Listening to this chapter", the reading's
  title, the book and its author, the scrubber with the time gone and the
  time left, the previous and next readings, fifteen seconds back and on,
  the gold play, and the speed. The app's sleep timer, its lock screen and
  saving for offline are not here.

  Drawn once by the server and driven by the `BookPlayer` hook
  (`assets/js/hooks/book_player.js`), which plays the recording in the
  browser from the Internet Archive and keeps the place in it in this
  browser's storage. Hidden until a reading is handed to the voice.
  """
  use LumenViaeWeb, :html

  @rates [0.75, 1.0, 1.25, 1.5, 2.0]

  @doc "The speeds a reading can be heard at (`AudioService.supportedRates`)."
  def rates, do: @rates

  @doc "A speed as the app labels it: \"1×\", \"1.5×\"."
  def rate_label(rate) when rate == trunc(rate), do: "#{trunc(rate)}×"
  def rate_label(rate), do: "#{rate}×"

  attr :book, :map, required: true

  def player(assigns) do
    assigns = assign(assigns, :rates, @rates)

    ~H"""
    <div class="bp-player" data-role="player" hidden>
      <section
        class="bp-panel"
        id="book-player-panel"
        data-role="panel"
        aria-labelledby="book-player-title"
        hidden
      >
        <p class="bp-panel__kicker">Listening to this chapter</p>
        <h2 class="bp-panel__title" id="book-player-title" data-role="track-title">
          The reading
        </h2>
        <p class="bp-panel__book">
          {@book.title} <span class="bp-panel__author">· {@book.author}</span>
        </p>

        <input
          type="range"
          class="chant-scrub bp-scrub"
          min="0"
          max="0"
          step="1"
          value="0"
          disabled
          aria-label="Position in this reading"
          data-role="scrub"
        />
        <div class="chant-clock" aria-hidden="true">
          <span data-role="elapsed">0:00</span>
          <span data-role="remaining">−0:00</span>
        </div>

        <div class="bp-controls">
          <button
            type="button"
            class="chant-step bp-step"
            data-act="previous"
            aria-label="Previous reading"
          >
            <span class="hero-backward-solid size-5" aria-hidden="true" />
          </button>
          <button type="button" class="chant-step" data-act="back" aria-label="Back fifteen seconds">
            <span class="bp-skip" aria-hidden="true">
              <span class="hero-arrow-uturn-left size-5" /><span class="bp-skip__n">15</span>
            </span>
          </button>
          <button
            type="button"
            class="chant-gold-play bp-play"
            data-act="toggle"
            data-role="play"
            aria-label="Play the reading"
            aria-pressed="false"
          >
            <span class="hero-play-solid size-6 chant-gold-play__play" aria-hidden="true" />
            <span class="hero-pause-solid size-6 chant-gold-play__pause" aria-hidden="true" />
          </button>
          <button
            type="button"
            class="chant-step"
            data-act="forward"
            aria-label="Forward fifteen seconds"
          >
            <span class="bp-skip" aria-hidden="true">
              <span class="hero-arrow-uturn-right size-5" /><span class="bp-skip__n">15</span>
            </span>
          </button>
          <button type="button" class="chant-step bp-step" data-act="next" aria-label="Next reading">
            <span class="hero-forward-solid size-5" aria-hidden="true" />
          </button>
        </div>

        <div class="bp-speed">
          <p class="bp-speed__label" id="book-player-speed">Speed</p>
          <div class="bp-speed__pills" role="group" aria-labelledby="book-player-speed">
            <button
              :for={rate <- @rates}
              type="button"
              class="bp-pill"
              data-act="rate"
              data-rate={rate}
              aria-pressed="false"
              aria-label={"Reading speed #{rate_label(rate)}"}
            >
              {rate_label(rate)}
            </button>
          </div>
        </div>
        <p class="bp-note">LibriVox readers are volunteers, and they read at their own pace.</p>
      </section>

      <div class="bp-mini" data-role="mini">
        <button
          type="button"
          class="bp-mini__open"
          data-act="expand"
          aria-expanded="false"
          aria-controls="book-player-panel"
        >
          <span class="hero-speaker-wave size-4 shrink-0 text-gilt" aria-hidden="true" />
          <span class="bp-mini__title" data-role="mini-title">The reading</span>
          <span class="hero-chevron-up size-4 shrink-0 bp-mini__chevron" aria-hidden="true" />
        </button>
        <button type="button" class="bp-mini__act" data-act="back" aria-label="Back fifteen seconds">
          <span class="bp-skip" aria-hidden="true">
            <span class="hero-arrow-uturn-left size-4" /><span class="bp-skip__n">15</span>
          </span>
        </button>
        <button
          type="button"
          class="bp-mini__act"
          data-act="toggle"
          data-role="mini-play"
          aria-label="Play"
          aria-pressed="false"
        >
          <span class="hero-play-solid size-5" data-icon="play" aria-hidden="true" />
          <span class="hero-pause-solid size-5" data-icon="pause" aria-hidden="true" hidden />
        </button>
      </div>
      <p class="bp-error" data-role="error" role="status" hidden></p>
    </div>
    """
  end
end
