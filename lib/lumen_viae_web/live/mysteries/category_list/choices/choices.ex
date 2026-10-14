defmodule LumenViaeWeb.Live.Mysteries.CategoryList.Choices do
  @moduledoc """
  "Your Rosary Today": the choices every Pray link on the page carries,
  in the app's words (RosaryForm.swift). Shown as one line saying how the
  Rosary will be prayed, with Change opening the choices beneath it, so
  the ways to pray come straight after. Audio, then Counting while the
  voice reads only the meditation, then the voice when there is more than
  one. Native radios in one form, so the browser gives each group arrow
  keys and a name; the `RosaryChoices` hook restores and remembers them.
  The form is always in the page, hidden or not, so the hook always runs.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Mysteries.CategoryList.PrayLinks

  attr :choices, :map, required: true
  attr :voices, :list, required: true

  def rosary_choices(assigns) do
    ~H"""
    <section aria-labelledby="choices-heading" class="category-choices">
      <div class="flex items-center gap-3">
        <div class="flex-1 min-w-0">
          <h2 id="choices-heading" class="font-display text-lg font-semibold text-ink-light">
            Your Rosary Today
          </h2>
          <p id="choices-summary" class="font-garamond text-base text-ink-muted leading-snug">
            {summary(@choices, @voices)}
          </p>
        </div>
        <button
          type="button"
          id="choices-toggle"
          class="category-quiet-btn shrink-0"
          aria-expanded="false"
          aria-controls="rosary-choices"
          phx-click={
            JS.toggle(to: "#rosary-choices")
            |> JS.toggle_attribute({"aria-expanded", "true", "false"})
          }
        >
          Change
        </button>
      </div>

      <form
        id="rosary-choices"
        class="hidden mt-3 border-t border-night-border"
        phx-change="choose"
        phx-hook="RosaryChoices"
      >
        <p class="font-garamond text-base text-ink-muted pt-3">
          Whichever way you pray below, it will be prayed like this.
        </p>
        <.choice_group
          name="aloud"
          legend="Audio"
          options={[{"false", "Meditation only"}, {"true", "Whole Rosary aloud"}]}
          selected={to_string(@choices.aloud)}
          note={audio_note(@choices.aloud)}
        />

        <.choice_group
          :if={not @choices.aloud}
          name="count"
          legend="Counting"
          options={[
            {"beads", PrayLinks.count_name("beads")},
            {"screen", PrayLinks.count_name("screen")}
          ]}
          selected={@choices.count}
          note={count_note(@choices.count)}
        />
        <p :if={@choices.aloud} class="category-choice-note py-3 border-b border-night-border">
          With the Whole Rosary, the voice moves the beads on the screen.
        </p>

        <.choice_group
          :if={length(@voices) > 1}
          name="voice"
          legend="Voice"
          options={Enum.map(@voices, &{&1.slug, &1.name})}
          selected={@choices.voice}
          note={voice_note(@voices, @choices.voice)}
        />
      </form>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :legend, :string, required: true
  attr :options, :list, required: true
  attr :selected, :string, required: true
  attr :note, :string, required: true

  defp choice_group(assigns) do
    ~H"""
    <fieldset
      class="min-w-0 py-3 border-b border-night-border"
      aria-describedby={"choice-#{@name}-note"}
    >
      <legend class="font-display text-lg font-semibold text-ink-light mb-2 float-left w-full">
        {@legend}
      </legend>
      <div class="category-pill clear-left">
        <label :for={{value, label} <- @options} class="category-pill-option">
          <input
            type="radio"
            name={"choices[#{@name}]"}
            value={value}
            checked={value == @selected}
            class="sr-only"
          />
          <span>{label}</span>
        </label>
      </div>
      <p id={"choice-#{@name}-note"} class="category-choice-note mt-2" aria-live="polite">
        {@note}
      </p>
    </fieldset>
    """
  end

  # How the Rosary will be prayed, in one line: the audio, the counting
  # while only the meditation is read, and the voice when there is a
  # choice of one.
  defp summary(choices, voices) do
    base = PrayLinks.summary(:meditation, choices)

    if choices.aloud or length(voices) < 2,
      do: base,
      else: base <> " · " <> PrayLinks.voice_name(choices.voice) <> " voice"
  end

  defp audio_note(true), do: "Every prayer is said aloud. Pray along with the voice."

  defp audio_note(false),
    do:
      "The meditation is read aloud. You say the prayers. In the Scriptural Rosary, the verses are read in silence."

  defp count_note("screen"), do: "The beads are on the screen. Tap or swipe for each Hail Mary."

  defp count_note(_beads),
    do: "Count on your own rosary. The screen shows one mystery at a time."

  defp voice_note(voices, slug) do
    case Enum.find(voices, &(&1.slug == slug)) do
      %{description: description} when is_binary(description) -> description
      _voice -> "The voice that reads aloud."
    end
  end
end
