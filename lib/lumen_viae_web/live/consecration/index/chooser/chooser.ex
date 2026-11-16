defmodule LumenViaeWeb.Live.Consecration.Index.Chooser do
  @moduledoc """
  The feast chooser (Abraham's pick, 16 Nov 2026, revised 23:14Z). Every
  feast's next preparation in one list in calendar order, which never
  moves: a tap only lights the row in place, the soonest lit until another
  is chosen. A row is the feast's name and the day it is kept this year,
  the first marked Soonest under its date. Above Begin the 33 days' two
  dates stand side by side, or stacked where they do not fit on one line
  each (the `ConsecrationSpan` hook); only they and Begin change as you
  tap. Start at any day serves a reader praying along with a book or a
  group. Begin is kept in this browser by the `ConsecrationPlan` hook. Only
  a preparation that can still begin on its Day 1 is offered.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Consecration.Plan

  import LumenViaeWeb.Live.Consecration.Parts

  attr :preparations, :list, required: true
  attr :selected, :map, default: nil
  attr :today, Date, required: true
  attr :any?, :boolean, default: false
  attr :any_day, :integer, default: 1
  attr :any_phase, :map, default: nil
  attr :completed?, :boolean, default: false
  attr :completed_on, Date, default: nil

  def chooser(assigns) do
    assigns =
      assign(assigns,
        soonest_id:
          case assigns.preparations do
            [first | _rest] -> first.feast.id
            [] -> nil
          end,
        selected_id: assigns.selected && assigns.selected.feast.id
      )

    ~H"""
    <section class="cons-chooser" data-role="chooser">
      <div class="cons-intro__words">
        <.kicker>Your consecration day</.kicker>
        <h1 class="cons-intro__title">Choose your feast</h1>
        <p class="cons-intro__lead">The 33 days end on a feast of Mary.</p>
      </div>

      <.completed_note :if={@completed?}>
        <%= if @completed_on do %>
          Consecrated {Plan.full_date(@completed_on)} — renew whenever you wish
        <% else %>
          Consecration completed — renew whenever you wish
        <% end %>
      </.completed_note>

      <ul :if={@preparations != []} class="cons-feasts" data-role="feasts">
        <li :for={prep <- @preparations}>
          <button
            type="button"
            class={["cons-feast", prep.feast.id == @selected_id && "is-on"]}
            phx-click="select_feast"
            phx-value-id={prep.feast.id}
            aria-pressed={to_string(prep.feast.id == @selected_id)}
            data-role="feast-row"
            aria-label={feast_label(prep)}
          >
            <span class={["cons-radio", prep.feast.id == @selected_id && "is-on"]} aria-hidden="true"></span>
            <span class="cons-feast__name">{prep.feast.name}</span>
            <span class="cons-feast__date">
              {Plan.row_date(prep.feast_date)}
              <span :if={prep.feast.id == @soonest_id} class="cons-soonest" data-role="soonest">
                Soonest
              </span>
            </span>
          </button>
        </li>
      </ul>

      <div class="cons-foot" data-role="foot">
        <div
          :if={@selected}
          id="cons-span"
          class="cons-span"
          phx-hook="ConsecrationSpan"
          data-role="span"
          data-pairs={span_pairs(@preparations)}
        >
          <p class="cons-span__end">
            <span class="cons-span__label">You begin</span>
            <span class="cons-span__date">{Plan.day_date(@selected.start)}</span>
          </p>
          <span class="cons-span__arrow" aria-hidden="true"></span>
          <p class="cons-span__end cons-span__end--to">
            <span class="cons-span__label">You consecrate</span>
            <span class="cons-span__date">
              {Plan.day_date(Plan.consecration_date(@selected.start))}
            </span>
          </p>
        </div>
        <button
          :if={@selected}
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
      </div>

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
    </section>
    """
  end

  # Every feast's two dates, so the hook picks one layout for them all and
  # the foot keeps its shape as the reader taps from feast to feast.
  defp span_pairs(preparations) do
    preparations
    |> Enum.map(&[Plan.day_date(&1.start), Plan.day_date(Plan.consecration_date(&1.start))])
    |> Jason.encode!()
  end

  # The row reads its name and the day the feast is kept, as it shows them.
  defp feast_label(prep), do: "#{prep.feast.name}, #{Plan.full_date(prep.feast_date)}"
end
