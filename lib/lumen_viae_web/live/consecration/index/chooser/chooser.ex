defmodule LumenViaeWeb.Live.Consecration.Index.Chooser do
  @moduledoc """
  The feast chooser, as the app's `ConsecrationDateSelectionView`: the
  feast chosen in one card (the soonest until another is chosen) with its
  Consecration Day and its Day 1, the other feasts as a short ruled list
  (three, then Show more feasts), Start at any day for a reader praying
  along with a book or a group, and one act, Begin, which the
  `ConsecrationPlan` hook keeps in this browser. Only a preparation that
  can still begin on its Day 1 is offered.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Consecration.Plan

  import LumenViaeWeb.Live.Consecration.Parts

  @others_shown 3

  attr :preparations, :list, required: true
  attr :selected, :map, default: nil
  attr :today, Date, required: true
  attr :more?, :boolean, default: false
  attr :any?, :boolean, default: false
  attr :any_day, :integer, default: 1
  attr :any_phase, :map, default: nil
  attr :completed?, :boolean, default: false
  attr :completed_on, Date, default: nil

  def chooser(assigns) do
    others =
      if assigns.selected,
        do: Enum.reject(assigns.preparations, &(&1.feast.id == assigns.selected.feast.id)),
        else: []

    assigns =
      assign(assigns,
        others: if(assigns.more?, do: others, else: Enum.take(others, @others_shown)),
        hidden?: !assigns.more? and length(others) > @others_shown,
        soonest?: assigns.selected && assigns.selected == List.first(assigns.preparations),
        days: assigns.selected && Plan.days_until(assigns.selected.start, assigns.today)
      )

    ~H"""
    <section class="cons-chooser" data-role="chooser">
      <div class="cons-intro__words">
        <.kicker>Your consecration day</.kicker>
        <h1 class="cons-intro__title">Choose your feast</h1>
        <p class="cons-intro__lead">The 33 days end on a feast of Mary: your Consecration Day.</p>
      </div>

      <.completed_note :if={@completed?}>
        <%= if @completed_on do %>
          Consecrated {Plan.full_date(@completed_on)} — renew whenever you wish
        <% else %>
          Consecration completed — renew whenever you wish
        <% end %>
      </.completed_note>

      <div :if={@selected} class="cons-card cons-card--elevated cons-chosen" data-role="chosen">
        <div class="cons-chosen__top">
          <span :if={@soonest?} class="cons-soonest">Soonest</span>
          <span class="cons-radio is-on" aria-hidden="true"></span>
        </div>
        <h2 class="cons-chosen__feast" data-role="chosen-feast">{@selected.feast.name}</h2>
        <p class="cons-chosen__date">{Plan.long_date(@selected.feast_date, @today)}</p>
        <.rule class="my-3.5" />
        <p class="cons-chosen__day-one" data-role="day-one">
          <span class="cons-chosen__label">Day 1</span>
          <span class="cons-chosen__start">
            {if @days == 0, do: "Today", else: Plan.long_date(@selected.start, @today)}
          </span>
          <span :if={@days > 0} class="cons-chosen__countdown">{Plan.countdown(@days)}</span>
        </p>
      </div>

      <div :if={@others != []} class="cons-others">
        <h2 class="cons-others__label">Other feasts</h2>
        <ul class="cons-others__list">
          <li :for={prep <- @others}>
            <button
              type="button"
              class="cons-feast"
              phx-click="select_feast"
              phx-value-id={prep.feast.id}
              data-role="feast-row"
              aria-label={"#{prep.feast.name}, #{Plan.long_date(prep.feast_date, @today)}. Day 1 is #{Plan.long_date(prep.start, @today)}."}
            >
              <span class="cons-radio" aria-hidden="true"></span>
              <span class="cons-feast__words">
                <span class="cons-feast__name">{prep.feast.name}</span>
                <span class="cons-feast__begins">
                  Begins {Plan.long_date(prep.start, @today, false)}
                </span>
              </span>
              <span class="cons-feast__date">{Plan.short_date(prep.feast_date, @today)}</span>
            </button>
          </li>
        </ul>
        <button
          :if={@hidden?}
          type="button"
          class="cons-more"
          phx-click="more_feasts"
          data-role="more-feasts"
        >
          Show more feasts
        </button>
      </div>

      <button
        type="button"
        class="btn-text cons-any-link"
        phx-click="any_start"
        aria-expanded={to_string(@any?)}
        aria-controls="cons-any"
        data-role="any-start"
      >
        Start at any day instead <span class="hero-chevron-right size-3" aria-hidden="true" />
      </button>

      <div
        :if={@any?}
        id="cons-any"
        class="cons-card cons-any"
        data-role="any-panel"
        aria-labelledby="cons-any-title"
      >
        <.kicker>Consecration to Mary</.kicker>
        <h2 id="cons-any-title" class="cons-any__title">Start at Any Day</h2>
        <p class="cons-any__lead">Praying along with a book or a group? Begin wherever they are.</p>
        <form phx-change="any_day" class="cons-any__form" id="cons-any-form">
          <label for="cons-any-day" class="sr-only">Start day</label>
          <select id="cons-any-day" name="day" class="cons-select" data-role="any-day">
            <option :for={d <- 1..33} value={d} selected={d == @any_day}>Day {d}</option>
          </select>
        </form>
        <p :if={@any_phase} class="cons-any__phase">
          {@any_phase.name} — {@any_phase.subtitle}
        </p>
        <p class="cons-any__date" data-role="any-date">
          Consecration Day: {Plan.full_date(Plan.consecration_date(Plan.start_at(@any_day, @today)))}
        </p>
        <button
          type="button"
          class="btn-gold cons-any__begin"
          data-consecration-begin
          data-start={Date.to_iso8601(Plan.start_at(@any_day, @today))}
          data-role="any-begin"
        >
          Begin today at Day {@any_day} <span class="hero-chevron-right size-4" aria-hidden="true" />
        </button>
      </div>

      <div :if={@selected} class="cons-foot">
        <button
          type="button"
          class="btn-gold cons-foot__act"
          data-consecration-begin
          data-start={Date.to_iso8601(@selected.start)}
          data-feast={@selected.feast.id}
          data-role="begin"
        >
          {Plan.begin_title(@selected, @today)}
          <span class="hero-chevron-right size-4" aria-hidden="true" />
        </button>
        <p class="cons-foot__note">
          {if @days == 0,
            do: "Your first day's prayers open right away.",
            else: "You can choose another feast until Day 1 begins."}
        </p>
      </div>
    </section>
    """
  end
end
