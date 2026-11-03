defmodule LumenViaeWeb.Live.Consecration.Day.Journey do
  @moduledoc """
  The journey card, as the app's: the five stages as one road, each
  segment as long as its days (Consecration Day given three days' width),
  the days prayed filled in gold, the stage shown ringed and today's
  stage marked beneath; the stage shown by name between the ways to its
  neighbours, with its span and what has been prayed in it; and its days,
  seven to a row, the days prayed filled, today ringed, the day being
  read ringed again. Today and the days prayed come from this browser's
  plan; without one the road is bare. Every day is a link: the website
  opens any day to anyone, where the app keeps the days ahead closed.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Consecration.Days

  import LumenViaeWeb.Live.Consecration.Parts

  attr :doc, :any, required: true
  attr :shown, :map, required: true
  attr :number, :integer, required: true
  attr :today_day, :integer, default: nil
  attr :done, :list, default: []

  def journey(assigns) do
    phases = assigns.doc.phases
    index = Enum.find_index(phases, &(&1.id == assigns.shown.id)) || 0

    assigns =
      assign(assigns,
        phases: phases,
        previous: if(index > 0, do: Enum.at(phases, index - 1)),
        next: Enum.at(phases, index + 1),
        prayed: Enum.count(assigns.done, &(&1 <= 33)),
        days: Days.phase_days(assigns.shown)
      )

    ~H"""
    <section class="cons-card cons-journey" aria-labelledby="journey-heading" data-role="journey">
      <.card_heading id="journey-heading" title="Your journey" meta={"#{@prayed} of 33 prayed"} />

      <div class="cons-road" role="group" aria-label="The five stages">
        <button
          :for={phase <- @phases}
          type="button"
          class={["cons-road__segment", phase.id == @shown.id && "is-shown"]}
          style={"flex-grow: #{max(phase.last_day - phase.first_day + 1, 3)}"}
          phx-click="show_phase"
          phx-value-id={phase.id}
          aria-pressed={to_string(phase.id == @shown.id)}
          aria-label={"#{phase.name}, #{phase.subtitle}"}
          data-role="road-segment"
        >
          <span class="cons-road__track">
            <span class="cons-road__fill" style={"width: #{fill(phase, @done)}%"}></span>
          </span>
          <span :if={now?(phase, @today_day)} class="cons-road__now" aria-hidden="true"></span>
        </button>
      </div>

      <div class="cons-stepper">
        <button
          type="button"
          class={["cons-stepper__arrow", !@previous && "is-none"]}
          phx-click="show_phase"
          phx-value-id={@previous && @previous.id}
          disabled={!@previous}
          aria-label={@previous && "Previous stage, #{@previous.name}"}
          aria-hidden={if(!@previous, do: "true")}
        >
          <span class="hero-chevron-left size-4" aria-hidden="true" />
        </button>
        <div class="cons-stepper__words" aria-live="polite">
          <p class="cons-stepper__name" data-role="shown-stage">
            {if now?(@shown, @today_day), do: "#{@shown.name} · Now", else: @shown.name}
          </p>
          <p class="cons-stepper__focus">{@shown.subtitle}</p>
          <p class="cons-stepper__span">{span(@shown, @today_day, @done)}</p>
        </div>
        <button
          type="button"
          class={["cons-stepper__arrow", !@next && "is-none"]}
          phx-click="show_phase"
          phx-value-id={@next && @next.id}
          disabled={!@next}
          aria-label={@next && "Next stage, #{@next.name}"}
          aria-hidden={if(!@next, do: "true")}
        >
          <span class="hero-chevron-right size-4" aria-hidden="true" />
        </button>
      </div>

      <ol class={["cons-days", length(@days) == 1 && "cons-days--one"]} aria-label={@shown.name}>
        <li :for={n <- @days}>
          <.link
            navigate={Days.day_path(n)}
            class={[
              "cons-day-dot",
              n in @done && "is-done",
              n == @today_day && "is-today",
              n == @number && "is-selected",
              @today_day && n > @today_day && "is-ahead"
            ]}
            aria-label={day_label(n, @done, @today_day)}
            aria-current={if(n == @number, do: "page")}
            data-role="day-dot"
          >
            <span aria-hidden="true">{n}</span>
          </.link>
        </li>
      </ol>
    </section>
    """
  end

  defp fill(phase, done) do
    days = Days.phase_days(phase)
    round(Enum.count(days, &(&1 in done)) / length(days) * 100)
  end

  defp now?(_phase, nil), do: false
  defp now?(phase, today), do: today >= phase.first_day and today <= phase.last_day

  # "Days 13–19 · 3 of 7 prayed"; a stage still ahead says so.
  defp span(phase, today, done) do
    label = Days.span_label(phase)
    days = Days.phase_days(phase)

    cond do
      today && phase.first_day > today ->
        "#{label} · still ahead"

      (kept = Enum.count(days, &(&1 in done))) > 0 ->
        "#{label} · #{kept} of #{length(days)} prayed"

      true ->
        label
    end
  end

  defp day_label(n, done, today) do
    name = if n == 34, do: "Consecration Day", else: "Day #{n}"
    name <> if(n in done, do: ", complete", else: "") <> if(n == today, do: ", today", else: "")
  end
end
