defmodule LumenViaeWeb.Live.Consecration.Index.Scheduled do
  @moduledoc """
  The waiting page, as the app's `ConsecrationScheduledView`: a
  consecration chosen ahead of its feast, until its Day 1 comes. When the
  33 days begin and the feast they end on, the book to read while
  waiting, and a way to choose another feast (which clears the plan in
  this browser; no day of it has been prayed). The Annunciation stands
  behind the title, as on the introduction's second page.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Consecration.{Days, Plan}

  import LumenViaeWeb.Live.Consecration.Parts
  import LumenViaeWeb.Live.Prayers.Painting

  attr :start, Date, required: true
  attr :today, Date, required: true
  attr :feasts, :list, required: true

  def scheduled(assigns) do
    days = Plan.days_until(assigns.start, assigns.today)

    assigns =
      assign(assigns,
        days: days,
        feast: Plan.feast_ending(assigns.feasts, assigns.start),
        feast_date: Plan.consecration_date(assigns.start)
      )

    ~H"""
    <section class="cons-scheduled" data-role="scheduled">
      <div class="cons-plate cons-plate--scheduled" aria-hidden="true">
        <.painting painting={{"joyful_annunciation", 0.5, 0.3}} sizes="100vw" loading="eager" />
      </div>

      <div class="cons-intro__words cons-scheduled__words">
        <.kicker>Consecration to Mary</.kicker>
        <h1 class="cons-intro__title cons-intro__title--long">
          {if @days == 1,
            do: "Your 33 days begin tomorrow",
            else: "Your 33 days begin #{Plan.long_date(@start, @today)}"}
        </h1>
        <p class="cons-intro__lead">
          The first day's prayers open then. Nothing is asked of you before it.
        </p>
      </div>

      <div class="cons-card cons-card--elevated cons-dates">
        <div class="cons-dates__row">
          <span class="cons-dates__label">Day 1</span>
          <span class="cons-dates__date" data-role="day-one">{Plan.long_date(@start, @today)}</span>
          <span class="cons-dates__note">{Plan.countdown(@days)}</span>
        </div>
        <.rule />
        <div class="cons-dates__row">
          <span class="cons-dates__label">Consecration Day</span>
          <span class="cons-dates__date" data-role="feast-date">
            {Plan.long_date(@feast_date, @today)}
          </span>
          <span :if={@feast} class="cons-dates__note" data-role="feast-name">{@feast.name}</span>
        </div>
      </div>

      <div class="cons-doors">
        <.link navigate={Days.book_path()} class="btn-text" data-role="read-book">
          <span class="hero-book-open size-4" aria-hidden="true" /> Read True Devotion to Mary
        </.link>
        <button
          type="button"
          class="btn-text cons-doors__quiet"
          data-consecration-restart
          data-role="another-feast"
        >
          Choose another feast
        </button>
      </div>
    </section>
    """
  end
end
