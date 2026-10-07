defmodule LumenViaeWeb.Live.Pray.PrayerText do
  @moduledoc """
  The words of the prayer page: a prayer, a Scriptural Rosary verse, a
  mystery's announcement and a set's meditation.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Pray.Sequence

  attr :prayer_id, :string, required: true
  attr :title, :string, default: nil, doc: "shown above the words; nil for none"
  attr :size, :string, default: "full", values: ~w(full quiet)

  def prayer(assigns) do
    assigns = assign(assigns, :lines, Sequence.prayer_lines(assigns.prayer_id))

    ~H"""
    <div>
      <h3 :if={@title} class="font-cinzel text-xs tracking-[0.22em] uppercase text-gold mb-3">
        {@title}
      </h3>
      <div class={[
        "font-garamond",
        if(@size == "full", do: "prayer-text text-cream/95", else: "prayer-text-quiet text-cream/75")
      ]}>
        <%= for line <- @lines do %>
          <p :if={elem(line, 0) == :rubric} class="italic text-gold-light/80 text-[0.9em] my-2">
            {elem(line, 1)}
          </p>
          <p :if={elem(line, 0) == :line}>{elem(line, 1)}</p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :verse, :map, required: true

  def verse(assigns) do
    ~H"""
    <figure class="prayer-verse">
      <blockquote class="font-garamond prayer-text text-cream">
        {@verse.text}
      </blockquote>
      <figcaption
        :if={@verse.reference}
        class="mt-3 font-cinzel text-xs tracking-[0.22em] uppercase text-gold-light/80"
      >
        {@verse.reference}
      </figcaption>
    </figure>
    """
  end

  attr :decade, :map, required: true
  attr :chaplet, :boolean, default: false

  def announcement(assigns) do
    ~H"""
    <header class="text-center">
      <p
        :if={@decade.label}
        class="font-cinzel text-xs tracking-[0.25em] uppercase text-gold-light/80"
      >
        {@decade.label}
      </p>
      <h2 class="mt-2 font-cinzel text-2xl md:text-3xl text-gold leading-snug">
        {@decade.name}
      </h2>
      <p :if={@decade.fruit} class="mt-3 font-garamond text-lg text-cream/80">
        <span class="font-cinzel text-xs tracking-[0.22em] uppercase text-gold-light/80">
          Ask for
        </span>
        <span class="text-gold/60" aria-hidden="true">&middot;</span>
        <span class="sr-only">:</span>
        {@decade.fruit}
      </p>
      <p
        :if={@decade.scripture_reference}
        class="mt-2 font-cinzel text-xs tracking-[0.22em] uppercase text-gold-light/60"
      >
        {@decade.scripture_reference}
      </p>
    </header>
    """
  end

  attr :meditation, :map, required: true
  attr :audio_url, :string, default: nil
  attr :pray_aloud, :boolean, default: false

  def meditation(assigns) do
    ~H"""
    <article class="max-w-[62ch] mx-auto">
      <div :if={!@pray_aloud} class="flex justify-center mb-6">
        <.audio_player audio_url={@audio_url} />
        <p
          :if={@meditation.audio_url && !@audio_url}
          class="font-cinzel text-xs tracking-[0.2em] uppercase text-gold-light/60 border border-gold/20 rounded-full px-4 py-2"
          title="This meditation has audio, but the audio URL could not be generated. Check that AWS credentials are configured on the server."
        >
          Audio unavailable
        </p>
      </div>

      <h3 :if={@meditation.title} class="font-cinzel text-base md:text-lg text-gold mb-4 text-center">
        {@meditation.title}
      </h3>

      <div class="font-garamond prayer-text text-cream/90 whitespace-pre-wrap">
        {@meditation.content}
      </div>

      <footer
        :if={@meditation.author || @meditation.source}
        class="mt-6 pt-4 border-t border-gold/20 text-right font-garamond text-gold-light italic"
      >
        <p :if={@meditation.author}>&mdash; {@meditation.author}</p>
        <p :if={@meditation.source} class="not-italic text-sm opacity-75 mt-1">
          {@meditation.source}
        </p>
      </footer>
    </article>
    """
  end
end
