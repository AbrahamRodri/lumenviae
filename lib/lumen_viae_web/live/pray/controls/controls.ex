defmodule LumenViaeWeb.Live.Pray.Controls do
  @moduledoc """
  The prayer page's controls: the way to pray it (form, counting, the
  closing prayers, the text size), praying aloud and its voice, the offer
  to continue where the reader left off, and Previous and Next.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Pray.{Params, Sequence}

  @form_names %{
    "meditation" => "With the meditations",
    "scriptural" => "The Scriptural Rosary",
    "holy" => "The prayers alone"
  }

  @form_notes %{
    "meditation" => "A meditation from the saints for each mystery.",
    "scriptural" => "A verse of Scripture before every Hail Mary.",
    "holy" => "Each mystery announced, and every prayer, with no readings."
  }

  attr :route, :atom, required: true
  attr :form, :string, required: true
  attr :count, :string, required: true
  attr :extras, :list, required: true
  attr :chaplet, :boolean, required: true

  def settings_panel(assigns) do
    assigns =
      assigns
      |> assign(:forms, Params.forms(assigns.route))
      |> assign(:closing_extras, Sequence.closing_extras())

    ~H"""
    <div
      id="prayer-settings"
      class="mt-3 rounded-2xl border border-gold/25 bg-navy-dark/70 px-4 py-5 sm:px-6 space-y-6"
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

      <fieldset>
        <legend class={legend_class()}>Counting</legend>
        <div class="mt-2 grid gap-2 sm:grid-cols-2">
          <.choice
            event="set_count"
            name="count"
            value="beads"
            pressed={@count == "beads"}
            title="On My Rosary"
            note="Count on your own rosary. The screen shows one mystery at a time."
          />
          <.choice
            event="set_count"
            name="count"
            value="screen"
            pressed={@count == "screen"}
            title="On the Screen"
            note="The beads are on the screen. Tap, swipe or press Space for each Hail Mary."
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
          do: "border-gold bg-gold/15",
          else: "border-gold/25 hover:border-gold/60"
        )
      ]}
    >
      <span class="block font-cinzel text-xs tracking-[0.18em] uppercase text-gold">{@title}</span>
      <span :if={@note} class="block mt-1 font-garamond text-base text-cream/70 leading-snug">
        {@note}
      </span>
    </button>
    """
  end

  attr :voices, :list, required: true
  attr :voice, :map, required: true
  attr :pray_aloud, :boolean, required: true

  def aloud_controls(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center justify-center gap-2">
      <button
        type="button"
        phx-click="toggle_pray_aloud"
        aria-pressed={to_string(@pray_aloud)}
        title="Hear every prayer of the Rosary, bead by bead"
        class={[
          "inline-flex items-center gap-2 rounded-full border px-4 min-h-11 font-cinzel text-[0.7rem] tracking-[0.2em] uppercase motion-safe:transition-colors",
          if(@pray_aloud,
            do: "border-gold bg-gold text-navy",
            else: "border-gold/40 text-gold-light/80 hover:border-gold hover:text-gold"
          )
        ]}
      >
        <span class="hero-speaker-wave size-4" aria-hidden="true" />
        {if @pray_aloud, do: "Praying aloud", else: "Pray aloud"}
      </button>

      <form :if={length(@voices) > 1} id="voice-form" phx-change="set_voice" class="inline-flex">
        <label for="narration-voice" class="sr-only">Narration voice</label>
        <select
          id="narration-voice"
          name="voice"
          class="rounded-full border border-gold/40 bg-navy min-h-11 pl-4 pr-9 font-cinzel text-[0.7rem] tracking-[0.2em] uppercase text-gold-light/80 focus:border-gold focus:ring-0"
        >
          <option :for={voice <- @voices} value={voice.slug} selected={voice.slug == @voice.slug}>
            {voice.name} voice
          </option>
        </select>
      </form>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :script, :list, required: true
  attr :start_screen, :integer, required: true
  attr :title, :string, required: true

  @doc "The spoken Rosary's player, driven by the SpokenRosary hook."
  def spoken_player(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="SpokenRosary"
      phx-update="ignore"
      data-script={Jason.encode!(@script)}
      data-start-screen={@start_screen}
      data-set-name={@title}
      class="max-w-sm mx-auto mt-3 rounded-2xl border border-gold/25 bg-navy-light/40 px-3 py-2"
    >
      <div class="flex items-center gap-1">
        <button type="button" data-back aria-label="Previous prayer" class={player_button_class()}>
          <span class="hero-backward size-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          data-play
          aria-label="Play"
          class="flex items-center justify-center w-11 h-11 shrink-0 rounded-full bg-gold hover:bg-gold-light text-navy"
        >
          <span class="hero-play-solid size-4 ml-0.5" aria-hidden="true" />
        </button>
        <button
          type="button"
          data-pause
          aria-label="Pause"
          class="hidden flex items-center justify-center w-11 h-11 shrink-0 rounded-full bg-gold hover:bg-gold-light text-navy"
        >
          <span class="hero-pause-solid size-4" aria-hidden="true" />
        </button>
        <button type="button" data-forward aria-label="Next prayer" class={player_button_class()}>
          <span class="hero-forward size-4" aria-hidden="true" />
        </button>
        <p data-caption class="flex-1 min-w-0 pl-2 font-garamond text-cream/90 text-base leading-snug">
        </p>
      </div>
      <div class="mt-2 h-px bg-gold/20">
        <div
          data-progress
          class="h-px bg-gold motion-safe:transition-[width] duration-500"
          style="width: 0%"
        >
        </div>
      </div>
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
      class="mt-4 rounded-2xl border border-gold/40 bg-navy-dark/70 px-4 py-4 text-center"
    >
      <p class="font-garamond text-lg text-cream/85">
        You were praying <span class="text-gold-light">{@resume.label}</span>.
      </p>
      <div class="mt-3 flex flex-col sm:flex-row items-stretch sm:items-center justify-center gap-2">
        <button type="button" phx-click="resume" class="btn-gold !py-2.5 min-h-11">
          Continue where you left off
        </button>
        <button
          type="button"
          phx-click="dismiss_resume"
          class="btn-outline-gold text-gold-light !py-2.5 min-h-11"
        >
          Start from the beginning
        </button>
      </div>
    </div>
    """
  end

  attr :count, :string, required: true
  attr :at_start, :boolean, required: true
  attr :at_end, :boolean, required: true

  def bottom_nav(assigns) do
    ~H"""
    <nav
      aria-label="Move through the Rosary"
      class="prayer-bottom-nav sticky bottom-0 z-10 -mx-4 sm:-mx-6 px-4 sm:px-6 pt-3 bg-gradient-to-t from-navy via-navy to-navy/0"
    >
      <div class="grid grid-cols-[auto_1fr] gap-3 items-center">
        <button
          type="button"
          phx-click="previous"
          disabled={@at_start}
          class="btn-outline-gold text-gold-light min-h-14 !px-5 disabled:opacity-30 disabled:cursor-not-allowed"
          aria-label={if @count == "screen", do: "Previous bead", else: "Previous"}
        >
          <span class="hero-arrow-left size-4" aria-hidden="true" />
          <span class="hidden sm:inline">Previous</span>
        </button>

        <button :if={@at_end} type="button" phx-click="complete" class="btn-gold min-h-14 w-full">
          Amen &middot; Complete
        </button>
        <button :if={!@at_end} type="button" phx-click="next" class="btn-gold min-h-14 w-full">
          {if @count == "screen", do: "Next bead", else: "Next"}
          <span class="hero-arrow-right size-4" aria-hidden="true" />
        </button>
      </div>
      <p class="hidden md:block mt-2 text-center font-cinzel text-[0.6rem] tracking-[0.2em] uppercase text-gold-light/50">
        {if @count == "screen",
          do: "Space, Enter or the arrow keys move a bead",
          else: "The left and right arrow keys turn the page"}
      </p>
    </nav>
    """
  end

  defp form_name(form), do: Map.fetch!(@form_names, form)
  defp form_note(form), do: Map.fetch!(@form_notes, form)

  defp legend_class,
    do: "font-cinzel text-[0.7rem] tracking-[0.25em] uppercase text-gold-light/80"

  defp size_button_class,
    do:
      "flex items-center justify-center w-11 h-11 rounded-full border border-gold/40 font-cinzel text-gold-light hover:border-gold"

  defp player_button_class,
    do:
      "flex items-center justify-center w-11 h-11 shrink-0 rounded-full text-gold-light/70 hover:text-gold"
end
