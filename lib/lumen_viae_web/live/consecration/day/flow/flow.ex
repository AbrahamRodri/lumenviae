defmodule LumenViaeWeb.Live.Consecration.Day.Flow do
  @moduledoc """
  A day walked a step a page, as the app's `ConsecrationDayFlowView`, on
  the phase's tinted ground: the way back to the day, the day's name over
  its beads (its index, `ConsecrationDayIndex`, opening from it) and "2 of
  6"; the step, a prayer (its Latin name over its title, the chant it is
  sung to where the Chant Library has one, its words in English, Latin or
  Both) or a reading (the stage and the day's title, the reading's title
  and source, its text); and the way on, Next, Go to the reading(s) after
  the last prayer, or Amen on the last step. From 1024px a rail of the
  day's steps stands beside it, as the Prayer Book's pray-along has.

  The chant plays through the `ChantGuest` hook in a box of its own for
  each step, so leaving a step stops it, as the app unloads its guest; it
  is not the site's chant player and never stands in the mini player. The app's
  sheet music is not on the website yet.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Consecration.Days

  import LumenViaeWeb.Live.Prayers.Prayer.Text

  @language_labels [{"english", "English"}, {"latin", "Latin"}, {"both", "Both"}]

  attr :number, :integer, required: true
  attr :day, :map, required: true
  attr :phase, :map, required: true
  attr :steps, :list, required: true
  attr :step, :integer, required: true
  attr :entry, :any, required: true
  attr :count, :integer, required: true
  attr :previous, :any, default: nil
  attr :next, :any, default: nil
  attr :language, :string, required: true
  attr :shown_language, :string, required: true
  attr :stanzas, :list, default: []
  attr :chant, :map, default: nil
  attr :today_day, :integer, default: nil

  def flow(assigns) do
    readings = Enum.count(assigns.steps, &match?({:reading, _}, &1))

    assigns =
      assign(assigns,
        languages: @language_labels,
        reading_count: readings,
        amen_to: amen_path(assigns.number, assigns.today_day, assigns.language)
      )

    ~H"""
    <div
      class={["pray-along__layout", @shown_language == "both" && "pray-along__layout--both"]}
      data-role="flow"
    >
      <nav class="pray-along__rail" aria-label={"The steps of #{Days.short_badge(@number)}"}>
        <p class="kicker mb-3">{Days.short_badge(@number)}</p>
        <ol>
          <li :for={{entry, i} <- Enum.with_index(@steps, 1)}>
            <.link
              patch={Days.step_path(@number, i, @language)}
              replace
              class={["pray-along__rail-link", i < @step && "is-prayed"]}
              aria-current={if(i == @step, do: "step")}
            >
              <span class="pray-along__rail-bead" aria-hidden="true"></span>
              <span class="min-w-0">{step_title(entry)}</span>
            </.link>
          </li>
        </ol>
      </nav>

      <div class="pray-along__column">
        <header class="pray-along__head">
          <div class="pray-along__bar">
            <.link
              navigate={Days.day_path(@number, @language)}
              class="pray-along__close"
              aria-label="Leave the day"
              data-role="close"
            >
              <span class="hero-x-mark size-5" aria-hidden="true" />
            </.link>
            <details class="cons-index" data-role="index">
              <summary class="cons-index__button">
                <span class="pray-along__kicker">{Days.short_badge(@number)}</span>
                <span class="hero-chevron-down size-3 text-gilt" aria-hidden="true" />
                <span class="sr-only">, the day's steps</span>
              </summary>
              <div class="cons-index__sheet">
                <p class="kicker">{Days.badge(@number)}</p>
                <p class="cons-index__title">{@day.title}</p>
                <ol>
                  <li :for={{entry, i} <- Enum.with_index(@steps, 1)}>
                    <.link
                      patch={Days.step_path(@number, i, @language)}
                      replace
                      class={["cons-index__row", i == @step && "is-here"]}
                      aria-current={if(i == @step, do: "step")}
                    >
                      <span class="cons-index__words">
                        <span class="cons-index__name">{step_title(entry)}</span>
                        <span :if={step_detail(entry)} class="cons-index__detail">
                          {step_detail(entry)}
                        </span>
                      </span>
                      <span :if={i == @step} class="cons-index__here">Here</span>
                      <span
                        :if={i != @step}
                        class="hero-chevron-right size-3 cons-caret"
                        aria-hidden="true"
                      />
                    </.link>
                  </li>
                </ol>
              </div>
            </details>
            <span class="w-11 shrink-0" aria-hidden="true"></span>
          </div>

          <div class="pray-along__beads-row">
            <ol class="pray-along__beads" aria-label="Steps">
              <li :for={{entry, i} <- Enum.with_index(@steps, 1)}>
                <.link
                  patch={Days.step_path(@number, i, @language)}
                  replace
                  class={["pray-along__bead", i < @step && "is-prayed", i == @step && "is-now"]}
                  aria-label={"#{i} of #{@count}, #{step_title(entry)}"}
                  aria-current={if(i == @step, do: "step")}
                >
                  <span aria-hidden="true"></span>
                </.link>
              </li>
            </ol>
            <p class="pray-along__count" data-role="step-count" aria-live="polite">
              {@step} of {@count}
            </p>
          </div>
        </header>

        <article class="pray-along__page" aria-labelledby="step-heading">
          <div class="pray-along__words">
            <%= case @entry do %>
              <% {:prayer, prayer} -> %>
                <p :if={Days.latin_title(prayer)} class="pray-along__second" data-role="second-title">
                  {Days.latin_title(prayer)}
                </p>
                <h1 id="step-heading" class="pray-along__title" data-role="step-title">
                  {prayer.title}
                </h1>
                <.sacred_divider cross={false} class="my-5" />

                <.chant_box :if={@chant} chant={@chant} step={@step} />

                <nav
                  :if={prayer.latin}
                  class="prayers-language mt-5"
                  aria-label="Language"
                  data-role="language"
                >
                  <.link
                    :for={{value, label} <- @languages}
                    patch={Days.step_path(@number, @step, value)}
                    replace
                    class="prayers-language__option"
                    aria-current={if(value == @shown_language, do: "true")}
                  >
                    {label}
                  </.link>
                </nav>

                <div class="mt-6 md:mt-8">
                  <.prayer_text stanzas={@stanzas} language={@shown_language} />
                </div>
              <% {:reading, reading} -> %>
                <p class="pray-along__second">{@phase.subtitle}</p>
                <h1 id="step-heading" class="pray-along__title" data-role="step-title">
                  {@day.title}
                </h1>
                <.sacred_divider cross={false} class="my-5" />
                <div class="cons-reading-head">
                  <p class="cons-reading-head__title" data-role="reading-title">{reading.title}</p>
                  <p :if={reading.source} class="cons-reading-head__source">{reading.source}</p>
                </div>
                <div class="book-text cons-reading-text" data-role="reading-text">
                  <%= for block <- Days.blocks(reading.text) do %>
                    <%= case block do %>
                      <% {:rule} -> %>
                        <.sacred_divider cross={false} class="my-6" />
                      <% {:heading, heading} -> %>
                        <h2 class="cons-reading-text__heading">{heading}</h2>
                      <% {:text, text, versal?} -> %>
                        <p class={["cons-paragraph", versal? && "cons-paragraph--versal"]}>{text}</p>
                    <% end %>
                  <% end %>
                </div>
            <% end %>
          </div>
        </article>

        <nav class="pray-along__foot" aria-label="Turn the page">
          <.link
            :if={@previous}
            patch={Days.step_path(@number, @step - 1, @language)}
            class="pray-along__back"
            rel="prev"
            data-role="previous"
            aria-label={"Back, #{step_title(@previous)}"}
          >
            <span class="hero-chevron-left size-5" aria-hidden="true" />
          </.link>

          <.link
            :if={@next}
            patch={Days.step_path(@number, @step + 1, @language)}
            class="pray-along__next"
            rel="next"
            data-role="next"
            aria-label={"#{forward(@entry, @next, @reading_count)}, #{step_title(@next)}"}
          >
            <span class="flex-1 min-w-0">
              <span class="pray-along__next-label">{forward(@entry, @next, @reading_count)}</span>
              <span class="pray-along__next-title">{step_title(@next)}</span>
            </span>
            <span class="hero-chevron-right size-4 text-gilt shrink-0" aria-hidden="true" />
          </.link>

          <.link
            :if={!@next}
            navigate={@amen_to}
            class="btn-gold pray-along__amen"
            data-consecration-amen
            data-day={@number}
            data-role="amen"
          >
            Amen <span class="hero-check size-4" aria-hidden="true" />
          </.link>
        </nav>
      </div>
    </div>
    """
  end

  attr :chant, :map, required: true
  attr :step, :integer, required: true

  defp chant_box(assigns) do
    ~H"""
    <div
      id={"cons-chant-#{@step}-#{@chant.id}"}
      class="cons-chant"
      phx-hook="ChantGuest"
      data-chant={@chant.id}
      data-role="chant"
    >
      <div id={"cons-chant-player-#{@step}"} phx-update="ignore" data-role="player">
        <audio src={@chant.audio.url} preload="metadata" data-role="audio"></audio>
        <div class="cons-transport">
          <button
            type="button"
            class="chant-gold-play cons-transport__play"
            data-act="toggle"
            data-role="play"
            aria-label={"Play #{@chant.latin_title}, sung"}
            aria-pressed="false"
            data-label={"#{@chant.latin_title}, sung"}
          >
            <span class="hero-play-solid size-5 chant-gold-play__play" aria-hidden="true" />
            <span class="hero-pause-solid size-5 chant-gold-play__pause" aria-hidden="true" />
          </button>
          <div class="cons-transport__line">
            <input
              type="range"
              class="chant-scrub"
              min="0"
              max={@chant.duration}
              step="0.1"
              value="0"
              aria-label="Position in the chant"
              data-role="scrub"
            />
            <div class="chant-clock" aria-hidden="true">
              <span data-role="elapsed">0:00</span>
              <span data-role="total">{Library.duration_label(@chant.duration)}</span>
            </div>
          </div>
        </div>
        <p class="chant-error" data-role="error" hidden>
          The chant couldn't be played. The prayer is here to pray.
        </p>
        <p class="cons-chant__credit">{Library.credit()}</p>
      </div>
    </div>
    """
  end

  @doc """
  Where Amen on day `number` goes, given today's day under the reader's
  plan (`today_day`, nil without one): a day ahead returns to itself,
  kept as nothing (the `ConsecrationPlan` hook keeps it only on its day
  or after); a day past returns to today's, as the app's journal does;
  Consecration Day goes on to the Act made only when it is today, or
  when there is no plan at all.
  """
  def amen_path(number, today_day, language \\ "english")
  def amen_path(34, nil, _language), do: Days.act_path()
  def amen_path(34, 34, _language), do: Days.act_path()

  def amen_path(number, today_day, language) when is_integer(today_day) and number < today_day,
    do: Days.day_path(today_day, language)

  def amen_path(number, _today_day, language), do: Days.day_path(number, language)

  @doc "A step's name: the prayer's title, or the reading's."
  def step_title({:prayer, prayer}), do: prayer.title
  def step_title({:reading, reading}), do: reading.title

  defp step_detail({:prayer, prayer}), do: Days.latin_title(prayer)
  defp step_detail({:reading, reading}), do: reading.source

  # The way on after the last prayer names the readings ahead.
  defp forward({:prayer, _}, {:reading, _}, 1), do: "Go to the reading"
  defp forward({:prayer, _}, {:reading, _}, _n), do: "Go to the readings"
  defp forward(_entry, _next, _n), do: "Next"
end
