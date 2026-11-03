defmodule LumenViaeWeb.Live.Consecration.Day.Overview do
  @moduledoc """
  A day's page, as the app's `ConsecrationDayOverviewView`: the arch hero
  with the badge, the day's title and its stage, and Pray (Begin today's
  prayer, Pray it again once prayed, Open day 5 for another day); the
  feast the 33 days count toward, under a plan; then the day in the order
  it is prayed, its prayers (a row each, opening the flow there), its
  readings (a preview each, opening the flow at it) and its question;
  the journey; the book; and Restart, under a plan.

  The app's reading carousel is the readings one under another, the page
  being wide enough; its Write in your journal is left out.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Consecration.{Days, Plan}

  import LumenViaeWeb.Live.Consecration.Parts
  import LumenViaeWeb.Live.Consecration.Day.Journey

  @language_labels [{"english", "English"}, {"latin", "Latin"}, {"both", "Both"}]

  attr :doc, :any, required: true
  attr :number, :integer, required: true
  attr :day, :map, required: true
  attr :phase, :map, required: true
  attr :prayers, :list, required: true
  attr :readings, :list, required: true
  attr :language, :string, required: true
  attr :plan, :map, default: nil
  attr :done, :list, default: []
  attr :today, Date, required: true
  attr :today_day, :integer, default: nil
  attr :today?, :boolean, default: false
  attr :done?, :boolean, default: false
  attr :feast, :map, default: nil
  attr :until_feast, :integer, default: nil
  attr :shown_phase, :map, required: true

  def overview(assigns) do
    assigns =
      assign(assigns,
        languages: @language_labels,
        prayer_steps: length(assigns.prayers)
      )

    ~H"""
    <article class="cons-day" aria-labelledby="day-heading" data-role="day">
      <section class="cons-hero" style={Days.tint_style(@phase)}>
        <.link
          :if={!@today?}
          navigate={Days.path()}
          class="book-back cons-hero__back"
          data-role="back"
        >
          <span class="hero-chevron-left size-4" aria-hidden="true" /> Consecration
        </.link>
        <.arch painting={Days.painting(@phase)} tinted class="cons-hero__arch" />
        <div class="cons-hero__words">
          <span class="badge-capsule" data-role="badge">{Days.badge(@number)}</span>
          <h1 id="day-heading" class="cons-hero__title">{@day.title}</h1>
          <p class="cons-hero__line" data-role="stage">{Days.subtitle(@phase, @day)}</p>
          <.link
            navigate={Days.step_path(@number, 1, @language)}
            class="btn-gold cons-hero__act"
            data-role="pray"
          >
            <span
              :if={@today? and not @done?}
              class="hero-play-solid size-4"
              aria-hidden="true"
            />
            {pray_title(@number, @today?, @done?)}
          </.link>
        </div>
      </section>

      <section :if={@plan} class="cons-feast-line" data-role="feast-line">
        <p class="cons-feast-line__label">
          <span class="cons-feast-line__rule" aria-hidden="true"></span>
          <span>{feast_label(@feast, @until_feast)}</span>
          <span class="cons-feast-line__rule" aria-hidden="true"></span>
        </p>
        <p class="cons-feast-line__date">{Plan.full_date(Plan.consecration_date(@plan.start))}</p>
        <p :if={@until_feast < 0} class="cons-feast-line__note">
          The days you completed still stand. Choose another feast whenever you're ready.
        </p>
      </section>

      <div class="cons-day__body">
        <div class="cons-day__cards">
          <section class="cons-card" aria-labelledby="day-prayers" data-role="prayers">
            <.card_heading
              id="day-prayers"
              title={if @today?, do: "Today's prayers", else: "The prayers"}
              meta={Days.prayer_count(length(@prayers))}
            />
            <nav class="prayers-language cons-language" aria-label="Language" data-role="language">
              <.link
                :for={{value, label} <- @languages}
                patch={Days.day_path(@number, value)}
                replace
                class="prayers-language__option"
                aria-current={if(value == @language, do: "true")}
              >
                {label}
              </.link>
            </nav>
            <ol class="cons-prayer-rows">
              <li :for={{prayer, i} <- Enum.with_index(@prayers, 1)}>
                <.link
                  navigate={Days.step_path(@number, i, @language)}
                  class="cons-prayer-row"
                  data-role="prayer-row"
                >
                  <span class="cons-prayer-row__bead" aria-hidden="true"></span>
                  <span class="cons-prayer-row__words">
                    <span class="cons-prayer-row__title">{row_title(prayer, @language)}</span>
                    <span :if={row_second(prayer, @language)} class="cons-prayer-row__second">
                      {row_second(prayer, @language)}
                    </span>
                  </span>
                  <span class="hero-chevron-right size-3 cons-caret" aria-hidden="true" />
                </.link>
              </li>
            </ol>
          </section>

          <section class="cons-card" aria-labelledby="day-readings" data-role="readings">
            <.card_heading id="day-readings" title={reading_heading(@today?, length(@readings))} />
            <ol class="cons-readings">
              <li :for={{reading, i} <- Enum.with_index(@readings)}>
                <.link
                  navigate={Days.step_path(@number, @prayer_steps + i + 1, @language)}
                  class="cons-reading"
                  data-role="reading-row"
                >
                  <span class="cons-reading__title">{reading.title}</span>
                  <span class="cons-reading__preview">{Days.preview(reading)}</span>
                  <span :if={reading.source} class="cons-reading__source">{reading.source}</span>
                </.link>
              </li>
            </ol>
            <.link
              navigate={Days.step_path(@number, @prayer_steps + 1, @language)}
              class="btn-text"
              data-role="read-in-full"
            >
              <span class="hero-book-open size-4" aria-hidden="true" /> Read in full
              <span class="hero-chevron-right size-3" aria-hidden="true" />
            </.link>
          </section>

          <section
            :if={@day.journal_prompt not in [nil, ""]}
            class="cons-card"
            aria-labelledby="day-reflection"
            data-role="reflection"
          >
            <.card_heading
              id="day-reflection"
              title={if @today?, do: "Today's reflection", else: "The reflection"}
            />
            <p class="cons-reflection">{@day.journal_prompt}</p>
          </section>
        </div>

        <div class="cons-day__cards">
          <.journey
            doc={@doc}
            shown={@shown_phase}
            number={@number}
            today_day={@today_day}
            done={@done}
          />
          <.book_card />
          <.restart :if={@plan} />
        </div>
      </div>
    </article>
    """
  end

  @doc "The quiet Restart, asked again before it clears this browser's plan."
  def restart(assigns) do
    ~H"""
    <details class="cons-restart" data-role="restart">
      <summary class="btn-text cons-restart__summary">Restart consecration</summary>
      <div class="cons-restart__ask">
        <p class="cons-restart__title">Restart your consecration?</p>
        <p class="cons-restart__note">
          The days you have prayed will be cleared so you can begin again.
        </p>
        <button
          type="button"
          class="btn-outline-gold"
          data-consecration-restart
          data-role="restart-confirm"
        >
          Erase progress and start over
        </button>
      </div>
    </details>
    """
  end

  defp pray_title(_n, _today?, true), do: "Pray it again"
  defp pray_title(_n, true, false), do: "Begin today's prayer"
  defp pray_title(n, false, false), do: "Open day #{n}"

  defp feast_label(_feast, until) when is_integer(until) and until < 0,
    do: "Your consecration day has passed"

  defp feast_label(nil, _until), do: "Your consecration day"
  defp feast_label(feast, _until), do: feast.name

  defp reading_heading(true, 1), do: "Today's reading"
  defp reading_heading(true, _n), do: "Today's readings"
  defp reading_heading(false, 1), do: "The reading"
  defp reading_heading(false, _n), do: "The readings"

  # How a row reads under the language chosen: Latin means the Latin
  # title itself, Both leads with the English and the Latin beneath.
  defp row_title(prayer, "latin"), do: Days.latin_title(prayer) || prayer.title
  defp row_title(prayer, _language), do: prayer.title

  defp row_second(prayer, "both"), do: Days.latin_title(prayer)
  defp row_second(_prayer, _language), do: nil
end
