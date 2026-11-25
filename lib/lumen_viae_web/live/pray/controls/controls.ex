defmodule LumenViaeWeb.Live.Pray.Controls do
  @moduledoc """
  The prayer page's controls: Back, Play and Next, the row of READ, VOICE,
  TEXT and MORE under them and the sheets they open (the meditation, the
  voice and the prayers' speed, the text size, the language of the
  prayers, the words, the reading page and the images, the way to pray it
  and the closing prayers), the speaker for the Rosary said aloud, and the
  offer to continue where the reader left off.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Pray.{Params, PrayerText, Sequence}

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

  @sheets ~w(read voice text more)

  @doc "The sheets the bottom row opens, by name."
  def sheets, do: @sheets

  attr :sheet, :string, default: nil, doc: "the open sheet, or nil"
  attr :meditation, :map, default: nil, doc: "the mystery's meditation, which READ opens"
  attr :decade_name, :string, default: nil
  attr :route, :atom, required: true
  attr :heading, :string, required: true, doc: "the set's name, or the devotion's"
  attr :subheading, :string, default: nil
  attr :author, :string, default: nil
  attr :form, :string, required: true
  attr :extras, :list, required: true
  attr :chaplet, :boolean, required: true
  attr :language, :string, required: true
  attr :voices, :list, required: true
  attr :voice, :map, required: true

  @doc """
  The four sheets of the bottom row, as the app's: READ (the meditation
  as text), VOICE (the narrator and the prayers' speed), TEXT (the size,
  the prayers' language, the words, the reading page and the images) and
  MORE (how to pray, after the Rosary, the set and its author, Share).
  Each sits at the foot of the screen while the bar is hidden.

  VOICE, TEXT and MORE stay in the page and are hidden when shut, so the
  speed and display buttons, which their hooks keep, never lose their
  state; READ is drawn only while it is open. The
  PrayerSheets hook moves the focus into a sheet as it opens, keeps it
  there, and gives it back to the button that opened it.
  """
  def sheets_layer(assigns) do
    assigns =
      assigns
      |> assign(:forms, Params.forms(assigns.route))
      |> assign(:closing_extras, Sequence.closing_extras())
      |> assign(:rates, @rates)

    ~H"""
    <div id="prayer-sheets" phx-hook="PrayerSheets" data-open={@sheet}>
      <div
        :if={@sheet}
        phx-click="close_sheet"
        aria-hidden="true"
        class="fixed inset-0 z-20 bg-night/70 motion-safe:animate-[prayer-fade_0.2s_ease-out]"
      >
      </div>

      <%!-- Drawn only while open: the words are long, and a meditation not
           yet reached stays off the page. --%>
      <.sheet
        :if={@meditation && @sheet == "read"}
        name="read"
        title="The meditation"
        kicker={@decade_name}
        open={@sheet}
      >
        <PrayerText.meditation meditation={@meditation} />
      </.sheet>

      <.sheet name="voice" title="Playback" open={@sheet}>
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
          <p class="mt-2 font-garamond italic text-base text-ink-muted leading-snug">
            The prayers only; a meditation is always read at its own pace.
          </p>
        </fieldset>
      </.sheet>

      <.sheet name="text" title="Text" open={@sheet}>
        <fieldset>
          <legend class={legend_class()}>Size</legend>
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

        <div
          id="prayer-display-choices"
          phx-hook="DisplayChoices"
          phx-update="ignore"
          class="space-y-6"
        >
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
        </div>
      </.sheet>

      <.sheet name="more" title={@heading} kicker={@author} open={@sheet}>
        <:subtitle :if={@subheading}>{@subheading}</:subtitle>

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

        <div id="prayer-share" phx-update="ignore" class="border-t border-night-border pt-2">
          <button
            type="button"
            data-share
            data-title={@heading}
            class="flex items-center gap-4 w-full min-h-12 py-2 text-left font-garamond text-lg text-ink-light hover:text-gilt"
          >
            <span class="hero-arrow-up-on-square size-5 text-gilt" aria-hidden="true" /> Share
          </button>
          <p data-share-status role="status" class="font-garamond text-base text-ink-muted"></p>
        </div>
      </.sheet>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :title, :string, required: true
  attr :kicker, :string, default: nil
  attr :open, :string, default: nil
  slot :subtitle
  slot :inner_block, required: true

  defp sheet(assigns) do
    ~H"""
    <section
      id={"sheet-#{@name}"}
      data-prayer-sheet
      role="dialog"
      aria-modal="true"
      aria-labelledby={"sheet-#{@name}-title"}
      hidden={@open != @name}
      class="prayer-sheet fixed inset-x-0 bottom-0 z-30 max-h-[85dvh] overflow-y-auto overscroll-contain rounded-t-3xl border-t border-night-border bg-night-raised shadow-night"
    >
      <div class="max-w-[calc(62ch+3rem)] mx-auto px-4 sm:px-6 pt-5 pb-8 space-y-6">
        <header class="flex items-start gap-3">
          <div class="flex-1 min-w-0">
            <p :if={@kicker} class="kicker">{@kicker}</p>
            <h2
              id={"sheet-#{@name}-title"}
              class="font-display !font-normal text-2xl text-ink-light leading-snug"
            >
              {@title}
            </h2>
            <p
              :for={subtitle <- @subtitle}
              class="mt-0.5 font-garamond italic text-base text-ink-muted"
            >
              {render_slot(subtitle)}
            </p>
          </div>
          <button
            type="button"
            phx-click="close_sheet"
            aria-label="Done, close the sheet"
            class="kicker shrink-0 min-h-11 min-w-11 px-2 -mt-2 -mr-2 rounded-full hover:text-ink-light"
          >
            Done
          </button>
        </header>
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  attr :sheet, :string, default: nil

  attr :read, :boolean,
    default: false,
    doc: "whether this step's mystery has a meditation to read"

  @doc """
  The row under Back and Next, as the app's: each glyph with its name
  beneath. Through a mystery with a meditation, READ leads it in gold.
  """
  def sheet_row(assigns) do
    ~H"""
    <div
      id="prayer-sheet-row"
      class={[
        "mt-2 grid max-w-[62ch] mx-auto",
        if(@read, do: "grid-cols-4", else: "grid-cols-3")
      ]}
    >
      <.row_button
        :if={@read}
        name="read"
        label="Read"
        aria_label="Read the meditation"
        icon="hero-book-open"
        accent
        sheet={@sheet}
      />
      <.row_button
        name="voice"
        label="Voice"
        aria_label="Voice and speed"
        icon="hero-microphone"
        sheet={@sheet}
      />
      <.row_button name="text" label="Text" aria_label="Text options" sheet={@sheet} />
      <.row_button
        name="more"
        label="More"
        aria_label="More: how to pray, after the Rosary, share"
        icon="hero-ellipsis-horizontal"
        sheet={@sheet}
      />
    </div>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :aria_label, :string, required: true
  attr :icon, :string, default: nil, doc: "a hero icon; none is the text glyph, Aa"
  attr :accent, :boolean, default: false
  attr :sheet, :string, default: nil

  defp row_button(assigns) do
    ~H"""
    <button
      id={"sheet-button-#{@name}"}
      type="button"
      phx-click="open_sheet"
      phx-value-sheet={@name}
      aria-label={@aria_label}
      aria-haspopup="dialog"
      aria-expanded={to_string(@sheet == @name)}
      aria-controls={"sheet-#{@name}"}
      class={[
        "flex flex-col items-center justify-center gap-1 min-h-14 min-w-11 px-1 rounded-xl hover:text-gilt motion-safe:transition-colors",
        if(@accent, do: "text-gilt", else: "text-ink-muted")
      ]}
    >
      <span :if={@icon} class={[@icon, "size-5"]} aria-hidden="true" />
      <span
        :if={!@icon}
        class="flex items-center h-5 font-garamond text-lg leading-none"
        aria-hidden="true"
      >
        Aa
      </span>
      <span class="font-display text-xs uppercase tracking-[0.12em] leading-none">{@label}</span>
    </button>
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
      <span
        :if={@note}
        class={[
          "block mt-1 font-garamond text-base leading-snug",
          if(@pressed, do: "text-ink-light", else: "text-ink-muted")
        ]}
      >
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
      <span class="prayer-choice__note block mt-1 font-garamond text-base text-ink-muted leading-snug">
        {@note}
      </span>
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
      data-script={Jason.encode!(Enum.filter(@script, & &1.url))}
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
    <%!-- Floats just above Back and Next, over the page, so it never moves
         the prayer; it stays until the reader answers it or moves a bead. --%>
    <div
      id="resume-banner"
      role="region"
      aria-label="Continue where you left off"
      phx-remove={
        JS.hide(
          transition: {"motion-safe:transition-opacity duration-200", "opacity-100", "opacity-0"},
          time: 200
        )
      }
      class="prayer-resume absolute inset-x-4 sm:inset-x-6 bottom-full mb-3 max-w-[62ch] mx-auto rounded-2xl border border-night-line bg-night-raised px-4 py-4 text-center shadow-night motion-safe:animate-[prayer-fade_0.35s_ease-out]"
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
  attr :sheet, :string, default: nil, doc: "the open sheet; the bar hides while one is"
  attr :read, :boolean, default: false, doc: "whether READ leads the row"
  slot :play, doc: "Play and pause, between Back and Next, when the set can be heard"

  attr :resume, :map,
    default: nil,
    doc: "the place a returning reader left off, offered above the bar"

  @doc """
  Back, Play and Next in one row, as the app has them: the three of equal
  weight, Play in the middle when there is a recording, and Amen (which
  completes the Rosary) in Next's place on the last bead. Under them, the
  row of sheets (`sheet_row/1`).
  """
  def bottom_nav(assigns) do
    ~H"""
    <nav
      aria-label="Move through the Rosary"
      hidden={@sheet != nil}
      class="prayer-bottom-nav sticky bottom-0 z-10 -mx-4 sm:-mx-6 px-4 sm:px-6 pt-3"
    >
      <.resume_banner :if={@resume} resume={@resume} />
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
          <span aria-hidden="true">&lsaquo;</span> <span class="prayer-step-word">Back</span>
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
          <span class="prayer-step-word">Next</span> <span aria-hidden="true">&rsaquo;</span>
        </button>
      </div>
      <.sheet_row sheet={@sheet} read={@read} />
      <p class="hidden md:block mt-1 text-center font-garamond text-base text-ink-muted">
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
