defmodule LumenViaeWeb.Live.Consecration.Index.Intro do
  @moduledoc """
  The introduction's pages, as the app's `ConsecrationOnboardingView`:
  the welcome under the Coronation in its arch, what the devotion is
  under the Annunciation, what each day holds (shown as the first day
  itself), and the 33 days' path in five stages; then the feast chooser.
  A bar over them goes back a page, marks the page among five, and skips
  to the chooser.

  The third page's Reflect says the day's one question and no more: the
  app's journal, where it is answered, is not on the website.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Consecration.{Days, Index}

  import LumenViaeWeb.Live.Consecration.Parts
  import LumenViaeWeb.Live.Prayers.Painting

  attr :step, :string, required: true
  attr :steps, :list, required: true

  def intro_bar(assigns) do
    assigns =
      assign(assigns,
        previous: Index.previous_step(assigns.step),
        index: Enum.find_index(assigns.steps, &(&1 == assigns.step)) || 0
      )

    ~H"""
    <div class={["cons-intro-bar", @step == "devotion" && "cons-intro-bar--over-art"]}>
      <.link
        :if={@previous}
        patch={Index.step_path(@previous)}
        class="cons-round"
        aria-label="Back"
        data-role="intro-back"
      >
        <span class="hero-chevron-left size-5" aria-hidden="true" />
      </.link>
      <span :if={!@previous} class="cons-round-space" aria-hidden="true"></span>

      <ol class="cons-progress" aria-label={"Page #{@index + 1} of #{length(@steps)}"}>
        <li
          :for={{s, i} <- Enum.with_index(@steps)}
          class={["cons-progress__mark", i <= @index && "is-lit", i == @index && "is-now"]}
          aria-hidden="true"
        >
          <span class="sr-only">{s}</span>
        </li>
      </ol>

      <.link
        :if={@step != "choose"}
        patch={Index.step_path("choose")}
        class="cons-skip"
        data-role="intro-skip"
        aria-label="Skip to choosing your feast"
      >
        Skip
      </.link>
      <span :if={@step == "choose"} class="cons-round-space" aria-hidden="true"></span>
    </div>
    """
  end

  attr :completed?, :boolean, default: false

  def welcome(assigns) do
    ~H"""
    <section class="cons-intro cons-intro--welcome" data-role="intro-welcome">
      <.arch painting={{"glorious_coronation", 0.5, 0.3}} class="cons-intro__arch" />
      <div class="cons-intro__words">
        <.kicker>33 days with Mary</.kicker>
        <h1 class="cons-intro__title">Consecration to Mary</h1>
        <p class="cons-intro__lead">
          A 33-day preparation to give yourself to Jesus through Mary
        </p>
      </div>
      <.completed_note :if={@completed?}>
        You completed this consecration. Many renew it each year.
      </.completed_note>
      <.link
        patch={Index.step_path("devotion")}
        class="btn-gold cons-intro__act"
        data-role="intro-next"
      >
        Learn how it works <span class="hero-arrow-right size-4" aria-hidden="true" />
      </.link>
    </section>
    """
  end

  def devotion(assigns) do
    ~H"""
    <section class="cons-intro cons-intro--devotion" data-role="intro-devotion">
      <div class="cons-plate" aria-hidden="true">
        <.painting painting={{"joyful_annunciation", 0.5, 0.3}} sizes="100vw" loading="eager" />
      </div>
      <div class="cons-intro__words cons-intro__words--low">
        <.kicker>The devotion</.kicker>
        <h1 class="cons-intro__title cons-intro__title--long">
          Everything you are, given to Jesus through Mary
        </h1>
        <.sacred_divider cross={false} class="my-5 self-stretch" />
      </div>
      <ol class="cons-lines">
        <li>
          <span class="cons-lines__numeral" aria-hidden="true">I</span>
          <span>Your prayers, works, joys and sufferings, placed in her hands</span>
        </li>
        <li>
          <span class="cons-lines__numeral" aria-hidden="true">II</span>
          <span>A renewal of the promises of your baptism</span>
        </li>
        <li>
          <span class="cons-lines__numeral" aria-hidden="true">III</span>
          <span>
            The way St. Louis de Montfort taught in his book <em>True Devotion to Mary</em>
          </span>
        </li>
      </ol>
      <.link patch={Index.step_path("day")} class="btn-gold cons-intro__act" data-role="intro-next">
        Continue <span class="hero-arrow-right size-4" aria-hidden="true" />
      </.link>
    </section>
    """
  end

  attr :doc, :any, required: true

  def each_day(assigns) do
    day = Days.day(assigns.doc, 1)
    phase = Days.phase(assigns.doc, day)

    assigns =
      assign(assigns,
        day: day,
        prayers: assigns.doc |> Days.prayers(phase) |> Enum.map_join(" · ", & &1.title),
        readings: day |> Days.readings() |> Enum.map_join(" · ", & &1.title)
      )

    ~H"""
    <section class="cons-intro" data-role="intro-day">
      <div class="cons-intro__words">
        <.kicker>Each day</.kicker>
        <h1 class="cons-intro__title cons-intro__title--long">The same three steps each day</h1>
        <p class="cons-intro__lead">Here is what your first day looks like.</p>
      </div>

      <div class="cons-card cons-card--elevated cons-first-day">
        <div class="cons-first-day__head">
          <span class="cons-first-day__label">Day 1</span>
          <span class="cons-first-day__title">{@day.title}</span>
        </div>
        <ol class="cons-first-day__steps">
          <li>
            <span class="cons-ring" aria-hidden="true">I</span>
            <span>
              <span class="cons-first-day__name">Pray</span>
              <span class="cons-first-day__detail">{@prayers}</span>
            </span>
          </li>
          <li>
            <span class="cons-ring" aria-hidden="true">II</span>
            <span>
              <span class="cons-first-day__name">Read</span>
              <span class="cons-first-day__detail">{@readings}</span>
            </span>
          </li>
          <li>
            <span class="cons-ring" aria-hidden="true">III</span>
            <span>
              <span class="cons-first-day__name">Reflect</span>
              <span class="cons-first-day__detail">One question to sit with.</span>
            </span>
          </li>
        </ol>
      </div>

      <p class="cons-intro__note">Miss a day? Every day stays open. Return whenever you can.</p>

      <.link
        patch={Index.step_path("journey")}
        class="btn-gold cons-intro__act"
        data-role="intro-next"
      >
        Continue <span class="hero-arrow-right size-4" aria-hidden="true" />
      </.link>
    </section>
    """
  end

  attr :doc, :any, required: true

  def journey(assigns) do
    ~H"""
    <section class="cons-intro" data-role="intro-journey">
      <div class="cons-intro__words">
        <.kicker>The journey</.kicker>
        <h1 class="cons-intro__title">The Path to Consecration</h1>
      </div>

      <ol class="cons-path">
        <li
          :for={phase <- @doc.phases}
          class={["cons-path__row", phase.id == "consecration_day" && "is-final"]}
        >
          <span class="cons-path__days">{Days.range_label(phase)}</span>
          <span class="cons-path__accent" style={Days.accent_style(phase)} aria-hidden="true"></span>
          <span class="cons-path__words">
            <span class="cons-path__focus">{phase.subtitle}</span>
            <span class="cons-path__name">{phase.name}</span>
          </span>
        </li>
      </ol>

      <.link patch={Index.step_path("choose")} class="btn-gold cons-intro__act" data-role="intro-next">
        Choose my consecration day <span class="hero-arrow-right size-4" aria-hidden="true" />
      </.link>
    </section>
    """
  end
end
