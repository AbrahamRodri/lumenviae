defmodule LumenViaeWeb.Live.Pray.Controls do
  @moduledoc """
  The prayer page's controls: the way to pray it (form, the voice, the
  prayers' speed, the closing prayers, the language of the prayers, the
  reading page, the images, the text size), Play and the speaker for the
  Rosary said aloud, the offer to continue where the reader left off, and
  Back and Next.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Pray.{Params, Sequence}

  @form_names %{
    "meditation" => "With the meditations",
    "scriptural" => "The Scriptural Rosary",
    "holy" => "No meditation"
  }

  # The prayers' speeds, in steps with 1x in the middle, as the app offers
  # them; the SpokenRosary hook keeps the choice in this browser.
  @rates ~w(0.8 0.9 1 1.1 1.2 1.3)

  @form_notes %{
    "meditation" => "A meditation from the saints for each mystery.",
    "scriptural" => "A verse of Scripture before every Hail Mary.",
    "holy" =>
      "The Rosary prayed aloud: each mystery announced, and every prayer, with no readings."
  }

  attr :route, :atom, required: true
  attr :form, :string, required: true
  attr :extras, :list, required: true
  attr :chaplet, :boolean, required: true
  attr :language, :string, required: true
  attr :voices, :list, required: true
  attr :voice, :map, required: true

  def settings_panel(assigns) do
    assigns =
      assigns
      |> assign(:forms, Params.forms(assigns.route))
      |> assign(:closing_extras, Sequence.closing_extras())
      |> assign(:rates, @rates)

    ~H"""
    <div
      id="prayer-settings"
      class="mt-3 rounded-2xl border border-night-border bg-night-raised px-4 py-5 sm:px-6 space-y-6"
    >
      <fieldset>
        <legend class={legend_class()}>How to pray</legend>
        <div class="mt-2 grid gap-2 sm:grid-cols-2">
          <.choice
            :for={form <- @forms}
            event="set_form"
            name="form"
            value={form}
            pressed={@form == form}
            title={form_name(form)}
            note={form_note(form)}
          />
        </div>
      </fieldset>

      <fieldset :if={length(@voices) > 1}>
        <legend class={legend_class()}>Voice</legend>
        <div class="mt-2 grid gap-2 sm:grid-cols-2">
          <.choice
            :for={voice <- @voices}
            event="set_voice"
            name="voice"
            value={voice.slug}
            pressed={@voice.slug == voice.slug}
            title={voice.name}
            note={voice.description}
          />
        </div>
      </fieldset>

      <fieldset id="prayer-speed" phx-update="ignore">
        <legend class={legend_class()}>Prayer speed</legend>
        <p class="mt-1 font-garamond text-base text-ink-muted leading-snug">
          The prayers only; a meditation is always read at its own pace.
        </p>
        <div class="mt-2 flex flex-wrap gap-2" role="group" aria-label="Prayer speed">
          <button
            :for={rate <- @rates}
            type="button"
            data-prayer-rate={rate}
            aria-pressed={to_string(rate == "1")}
            class="prayer-choice flex items-center justify-center min-w-14 h-11 px-3 rounded-full border font-garamond text-ink-light motion-safe:transition-colors"
          >
            {rate}&times;
          </button>
        </div>
      </fieldset>

      <fieldset :if={!@chaplet}>
        <legend class={legend_class()}>After the Rosary</legend>
        <div class="mt-2 grid gap-2 sm:grid-cols-3">
          <.choice
            :for={extra <- @closing_extras}
            event="toggle_extra"
            name="extra"
            value={extra.id}
            pressed={extra.id in @extras}
            title={extra.title}
            note={extra.detail}
          />
        </div>
      </fieldset>

      <fieldset>
        <legend class={legend_class()}>Prayer language</legend>
        <div class="mt-2 grid gap-2 sm:grid-cols-2">
          <.choice
            :for={language <- Sequence.languages()}
            event="set_language"
            name="language"
            value={language}
            pressed={@language == language}
            title={language_name(language)}
            note={language_note(language)}
          />
        </div>
      </fieldset>

      <div id="prayer-display-choices" phx-hook="DisplayChoices" phx-update="ignore" class="space-y-6">
        <fieldset>
          <legend class={legend_class()}>Reading page</legend>
          <div class="mt-2 grid gap-2 sm:grid-cols-2">
            <.display_choice
              setting="reading-page"
              value="night"
              title="Night"
              note="The meditation on the dark, like the prayers."
            />
            <.display_choice
              setting="reading-page"
              value="vellum"
              title="Vellum"
              note="The meditation on a light page, like a book."
            />
          </div>
        </fieldset>

        <fieldset>
          <legend class={legend_class()}>Images</legend>
          <div class="mt-2 grid gap-2 sm:grid-cols-2">
            <.display_choice
              setting="prayer-images"
              value="on"
              title="Show"
              note="The mystery's painting beside its name."
            />
            <.display_choice
              setting="prayer-images"
              value="off"
              title="Hide"
              note="Words only."
            />
          </div>
        </fieldset>

        <fieldset>
          <legend class={legend_class()}>On the screen</legend>
          <button
            type="button"
            role="switch"
            data-display="prayer-words"
            data-toggle
            aria-checked="true"
            class="prayer-switch mt-2 flex items-center justify-between gap-4 w-full min-h-11 rounded-xl border px-4 py-3 text-left"
          >
            <span>
              <span class="block kicker text-gilt">Show Words and Beads</span>
              <span class="block mt-1 font-garamond text-base text-ink-muted leading-snug">
                Off, only the prayer's name stays.
              </span>
            </span>
            <span class="prayer-switch__track" aria-hidden="true">
              <span class="prayer-switch__thumb"></span>
            </span>
          </button>
        </fieldset>
      </div>

      <fieldset>
        <legend class={legend_class()}>Text size</legend>
        <div class="mt-2 flex items-center gap-2">
          <button type="button" data-text-size="-1" class={size_button_class()}>
            <span aria-hidden="true" class="text-sm">A</span>
            <span class="sr-only">Smaller text</span>
          </button>
          <button type="button" data-text-size="1" class={size_button_class()}>
            <span aria-hidden="true" class="text-xl">A</span>
            <span class="sr-only">Larger text</span>
          </button>
        </div>
      </fieldset>
    </div>
    """
  end

  attr :event, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :pressed, :boolean, required: true
  attr :title, :string, required: true
  attr :note, :string, default: nil

  defp choice(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@event}
      {%{"phx-value-#{@name}" => @value}}
      aria-pressed={to_string(@pressed)}
      class={[
        "text-left rounded-xl border px-4 py-3 min-h-11 motion-safe:transition-colors",
        if(@pressed,
          do: "border-gilt bg-gilt/15",
          else: "border-night-border hover:border-night-line"
        )
      ]}
    >
      <span class="block kicker text-gilt">{@title}</span>
      <span :if={@note} class="block mt-1 font-garamond text-base text-ink-muted leading-snug">
        {@note}
      </span>
    </button>
    """
  end

  attr :setting, :string, required: true
  attr :value, :string, required: true
  attr :title, :string, required: true
  attr :note, :string, required: true

  # A look chosen in this browser only, kept by the DisplayChoices hook,
  # which sets aria-pressed; the server never knows it.
  defp display_choice(assigns) do
    ~H"""
    <button
      type="button"
      data-display={@setting}
      data-value={@value}
      aria-pressed="false"
      class="prayer-choice text-left rounded-xl border px-4 py-3 min-h-11 motion-safe:transition-colors"
    >
      <span class="block kicker text-gilt">{@title}</span>
      <span class="block mt-1 font-garamond text-base text-ink-muted leading-snug">{@note}</span>
    </button>
    """
  end

  attr :id, :string, required: true
  attr :script, :list, required: true
  attr :start_screen, :integer, required: true
  attr :title, :string, required: true

  @doc """
  Play and pause for the Rosary said aloud, the middle of the bottom bar,
  driven by the SpokenRosary hook. Back and Next beside it move a bead, and
  the voice follows. The speaker that mutes it is `mute_button/1`, in the
  top bar.
  """
  def spoken_play(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="SpokenRosary"
      phx-update="ignore"
      data-script={Jason.encode!(@script)}
      data-start-screen={@start_screen}
      data-set-name={@title}
      class="flex justify-center"
    >
      <button type="button" data-play aria-label="Play" class={play_button_class()}>
        <span class="hero-play-solid size-6 ml-0.5" aria-hidden="true" />
      </button>
      <button type="button" data-pause aria-label="Pause" class={["hidden", play_button_class()]}>
        <span class="hero-pause-solid size-6" aria-hidden="true" />
      </button>
    </div>
    """
  end

  @doc """
  The speaker that mutes the Rosary said aloud. Muted, it keeps moving at
  the recording's pace, and the line being read is lit where the
  recording is timed. Left alone by the page (the hook keeps its state),
  so a player remounted for another voice stays muted.
  """
  def mute_button(assigns) do
    ~H"""
    <div id="prayer-mute" phx-update="ignore" class="shrink-0">
      <button
        type="button"
        data-mute
        aria-pressed="false"
        aria-label="Mute"
        title="Mute: the Rosary keeps going, and the words light up as they are read"
        class="flex items-center justify-center w-11 h-11 rounded-full text-ink-muted hover:text-gilt aria-pressed:text-gilt"
      >
        <span data-speaker-on class="hero-speaker-wave size-5" aria-hidden="true" />
        <span data-speaker-off class="hidden hero-speaker-x-mark size-5" aria-hidden="true" />
      </button>
    </div>
    """
  end

  attr :resume, :map, required: true

  def resume_banner(assigns) do
    ~H"""
    <div
      id="resume-banner"
      role="region"
      aria-label="Continue where you left off"
      class="mt-4 rounded-2xl border border-night-line bg-night-raised px-4 py-4 text-center"
    >
      <p class="font-garamond text-lg text-ink-light">
        You were praying <span class="text-gilt">{@resume.label}</span>.
      </p>
      <div class="mt-3 flex flex-col sm:flex-row items-stretch sm:items-center justify-center gap-2">
        <button
          type="button"
          phx-click={JS.push("resume") |> JS.focus(to: "#prayer-next")}
          class="btn-gold !py-2.5 min-h-11"
        >
          Continue where you left off
        </button>
        <button
          type="button"
          phx-click={JS.push("dismiss_resume") |> JS.focus(to: "#prayer-next")}
          class="btn-outline-gold !py-2.5 min-h-11"
        >
          Start from the beginning
        </button>
      </div>
    </div>
    """
  end

  attr :place, :string, required: true, doc: "the page and bead, so a move is seen"

  @doc """
  The one-time hint that a bead is swiped, as the app's `PrayerSwipeHint`
  teaches it: counting on the screen, on a touch screen, never while the
  voice is moving the beads. The SwipeHint hook shows it once in this
  browser, a moment after the page settles, and spends it as it is shown;
  it leaves after five seconds, at the first bead moved, or when
  dismissed. It teaches a shortcut, never a requirement: Next does
  everything the swipe does.
  """
  def swipe_hint(assigns) do
    ~H"""
    <div id="swipe-hint" phx-hook="SwipeHint" data-place={@place}>
      <div id="swipe-hint-body" phx-update="ignore">
        <p
          data-hint
          hidden
          class="mx-auto mb-3 flex w-fit items-center gap-2 rounded-full border border-night-border bg-night-raised pl-4 pr-1 font-garamond text-sm text-ink-light"
        >
          <span>Swipe left for the next bead</span>
          <span class="hero-arrow-left size-4 text-gilt" aria-hidden="true" />
          <button
            type="button"
            data-dismiss
            aria-label="Dismiss the hint"
            class="flex items-center justify-center w-11 h-11 rounded-full text-ink-muted hover:text-gilt"
          >
            <span class="hero-x-mark size-4" aria-hidden="true" />
          </button>
        </p>
      </div>
    </div>
    """
  end

  attr :at_start, :boolean, required: true
  attr :at_end, :boolean, required: true
  slot :play, doc: "Play and pause, between Back and Next, when the set can be heard"

  @doc """
  Back, Play and Next in one row, as the app has them: the three of equal
  weight, Play in the middle when there is a recording, and Amen (which
  completes the Rosary) in Next's place on the last bead.
  """
  def bottom_nav(assigns) do
    ~H"""
    <nav
      aria-label="Move through the Rosary"
      class="prayer-bottom-nav sticky bottom-0 z-10 -mx-4 sm:-mx-6 px-4 sm:px-6 pt-3"
    >
      <div class={[
        "grid gap-3 items-center max-w-[62ch] mx-auto",
        if(@play != [], do: "grid-cols-[1fr_auto_1fr]", else: "grid-cols-2")
      ]}>
        <button
          type="button"
          phx-click="previous"
          disabled={@at_start}
          class={[pill_class(), "border-night-line disabled:opacity-30 disabled:cursor-not-allowed"]}
          aria-label="Back a bead"
        >
          <span aria-hidden="true">&lsaquo;</span> Back
        </button>

        {render_slot(@play)}

        <button
          :if={@at_end}
          id="prayer-next"
          type="button"
          phx-click="complete"
          aria-label="Amen, complete the Rosary"
          class={["btn-gold min-h-14 w-full !px-3", label_class()]}
        >
          Amen
        </button>
        <button
          :if={!@at_end}
          id="prayer-next"
          type="button"
          phx-click="next"
          aria-label="Next bead"
          class={[pill_class(), "border-gilt"]}
        >
          Next <span aria-hidden="true">&rsaquo;</span>
        </button>
      </div>
      <p class="hidden md:block mt-2 text-center font-garamond text-base text-ink-muted">
        Space, Enter or the arrow keys move a bead
      </p>
    </nav>
    """
  end

  defp language_name("en"), do: "English"
  defp language_name("la"), do: "Latin"

  defp language_note("en"), do: "Every prayer in English."

  defp language_note("la"),
    do: "The prayers in Latin. The mysteries and Scripture stay in English."

  defp form_name(form), do: Map.fetch!(@form_names, form)
  defp form_note(form), do: Map.fetch!(@form_notes, form)

  defp legend_class,
    do: "kicker"

  defp size_button_class,
    do:
      "flex items-center justify-center w-11 h-11 rounded-full border border-night-line font-garamond text-ink-light hover:border-gilt"

  defp pill_class,
    do:
      "flex items-center justify-center gap-1.5 min-h-14 w-full px-4 rounded-full border bg-night/60 #{label_class()} text-ink-light hover:border-gilt hover:text-gilt motion-safe:transition-colors"

  # The app's spaced capitals for Back, Next and Amen: the pill's face
  # (Cinzel), at its weight.
  defp label_class, do: "font-display !font-normal text-sm uppercase tracking-[0.14em]"

  defp play_button_class,
    do:
      "flex items-center justify-center w-14 h-14 shrink-0 rounded-full border-2 border-gilt bg-night/60 text-gilt hover:bg-gilt/15"
end
