defmodule LumenViaeWeb.Live.Pray.Completion do
  @moduledoc """
  After Complete: the Rosary offered, the app's line for after praying,
  the days in a row this browser has prayed (kept in this browser only, by
  the PrayerStreak hook) and the ways back to the mysteries.
  """
  use LumenViaeWeb, :html

  alias LumenViae.Rosary.Categories
  alias LumenViaeWeb.Live.Pray.Sequence

  attr :category, :string, required: true
  attr :storage_key, :string, required: true

  def completion(assigns) do
    assigns = assign(assigns, :quote, Sequence.quote_after_praying())

    ~H"""
    <section
      id="prayer-complete"
      phx-hook="PrayerStreak"
      data-key={@storage_key}
      aria-labelledby="prayer-complete-title"
      class="flex-1 flex flex-col items-center justify-center text-center py-10 md:py-16"
    >
      <span
        class="flex items-center justify-center w-14 h-14 rounded-full border border-gold/60 shadow-glow"
        aria-hidden="true"
      >
        <span class="hero-check size-6 text-gold"></span>
      </span>

      <h2 id="prayer-complete-title" class="mt-6">
        <span class="block font-cinzel text-xs tracking-[0.25em] uppercase text-gold">
          {if @category == "seven_sorrows",
            do: "The Seven Sorrows are offered",
            else: "The Rosary is offered"}
        </span>
        <span class="block mt-2 font-cinzel text-4xl text-cream">Amen</span>
      </h2>

      <p
        id="prayer-streak"
        phx-update="ignore"
        id="prayer-streak"
        phx-update="ignore"
        data-streak
        aria-live="polite"
        class="mt-5 min-h-6 font-cinzel text-[0.7rem] tracking-[0.25em] uppercase text-gold-light/80"
      >
      </p>

      <.sacred_divider class="!my-8 w-full max-w-sm" />

      <figure :if={@quote} class="max-w-[52ch]">
        <blockquote class="font-garamond text-xl md:text-2xl text-cream/90 leading-relaxed">
          &ldquo;{@quote["text"]}&rdquo;
        </blockquote>
        <figcaption class="mt-4 font-cinzel text-[0.7rem] tracking-[0.22em] uppercase text-gold-light/80">
          {@quote["author"]}
        </figcaption>
      </figure>

      <div class="mt-10 flex flex-col sm:flex-row items-stretch sm:items-center gap-3 w-full sm:w-auto">
        <.link navigate={~p"/mysteries/#{@category}"} class="btn-gold min-h-11">
          Back to the {Categories.devotion_title(@category)}
        </.link>
        <.link navigate={~p"/"} class="btn-outline-gold text-gold-light min-h-11">
          All the mysteries
        </.link>
      </div>
    </section>
    """
  end
end
