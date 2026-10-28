defmodule LumenViaeWeb.Live.Pray.Completion do
  @moduledoc """
  After Complete: the Rosary offered, the app's line for after praying,
  the days in a row this browser has prayed (kept in this browser only, by
  the PrayerStreak hook), the devotional milestone reached today if there
  is one, and the ways back to the mysteries.

  Every milestone is in the page, hidden; the PrayerStreak hook shows the
  one the streak has just reached, and only on the day's first Rosary, as
  the app does, so it stays rare enough to be special.
  """
  use LumenViaeWeb, :html

  alias LumenViae.Rosary.Categories
  alias LumenViaeWeb.Live.Pray.Sequence

  attr :category, :string, required: true
  attr :storage_key, :string, required: true

  def completion(assigns) do
    assigns =
      assigns
      |> assign(:quote, Sequence.quote_after_praying())
      |> assign(:milestones, Sequence.milestones())

    ~H"""
    <section
      id="prayer-complete"
      phx-hook="PrayerStreak"
      data-key={@storage_key}
      aria-labelledby="prayer-complete-title"
      tabindex="-1"
      class="flex-1 flex flex-col items-center justify-center text-center py-10 md:py-16 focus:outline-none"
    >
      <span
        class="flex items-center justify-center w-14 h-14 rounded-full border border-night-line shadow-gilt"
        aria-hidden="true"
      >
        <span class="hero-check size-6 text-gilt"></span>
      </span>

      <h2 id="prayer-complete-title" class="mt-6">
        <span class="block kicker text-gilt">
          {if @category == "seven_sorrows",
            do: "The Seven Sorrows are offered",
            else: "The Rosary is offered"}
        </span>
        <span class="block mt-2 font-display font-semibold text-5xl text-ink-light">Amen</span>
      </h2>

      <p
        id="prayer-streak"
        phx-update="ignore"
        data-streak
        aria-live="polite"
        class="mt-5 min-h-6 kicker"
      >
      </p>

      <div id="prayer-milestones" phx-update="ignore" aria-live="polite" class="w-full max-w-sm">
        <div
          :for={milestone <- @milestones}
          data-milestone={milestone.days}
          hidden
          class="mt-4 rounded-2xl border border-night-line bg-night-raised px-5 py-4"
        >
          <p class="kicker">
            Milestone reached
          </p>
          <p class="mt-2 font-display font-semibold text-3xl text-ink-light">{milestone.name}</p>
          <p class="mt-2 font-garamond italic text-base text-ink-light leading-relaxed">
            {milestone.blessing}
          </p>
        </div>
      </div>

      <.sacred_divider class="!my-8 w-full max-w-sm" />

      <figure :if={@quote} class="max-w-[52ch]">
        <blockquote class="font-garamond text-xl md:text-2xl text-ink-light leading-relaxed">
          &ldquo;{@quote["text"]}&rdquo;
        </blockquote>
        <figcaption class="mt-4 kicker">
          {@quote["author"]}
        </figcaption>
      </figure>

      <div class="mt-10 flex flex-col sm:flex-row items-stretch sm:items-center gap-3 w-full sm:w-auto">
        <.link navigate={~p"/mysteries/#{@category}"} class="btn-gold min-h-11">
          Back to the {Categories.devotion_title(@category)}
        </.link>
        <.link navigate={~p"/"} class="btn-outline-gold min-h-11">
          All the mysteries
        </.link>
      </div>
    </section>
    """
  end
end
