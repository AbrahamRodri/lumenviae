defmodule LumenViaeWeb.Live.Mysteries.CategoryList.Choices do
  @moduledoc """
  "Your Rosary Today": the choices every Pray link on the page carries.
  The prayer page says every prayer aloud, so the only choice left is the
  narration voice, shown when there is more than one. On a phone one ruled
  row says which voice and opens the choice beneath it; a wide screen shows
  it open beside the shelf. Native radios in one form, so the browser gives
  the group arrow keys and a name; the `RosaryChoices` hook restores and
  remembers it. The form is always in the page, hidden or not, so the hook
  always runs.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Mysteries.CategoryList.PrayLinks

  attr :choices, :map, required: true
  attr :voices, :list, required: true

  def rosary_choices(assigns) do
    ~H"""
    <section aria-labelledby="choices-heading" class="category-choices">
      <h2 id="choices-heading" class="section-label">Your Rosary Today</h2>

      <%!-- On a phone one ruled row says how it will be prayed and opens the
            choices; a wide screen shows them open. --%>
      <button
        type="button"
        id="choices-toggle"
        class="category-choices-row"
        aria-expanded="false"
        aria-controls="rosary-choices"
        phx-click={
          JS.toggle(to: "#rosary-choices")
          |> JS.toggle_attribute({"aria-expanded", "true", "false"})
        }
      >
        <span class="category-choice-legend shrink-0">Voice</span>
        <span
          id="choices-summary"
          class="flex-1 min-w-0 text-right text-base text-ink-muted leading-snug"
        >
          {PrayLinks.summary(@choices) || "One voice"}
        </span>
        <span class="hero-chevron-down size-4 row-chevron" aria-hidden="true" />
      </button>

      <form
        id="rosary-choices"
        class="hidden lg:block"
        phx-change="choose"
        phx-hook="RosaryChoices"
      >
        <p class="italic text-base text-ink-muted pt-3 lg:pt-0">
          Whichever way you pray below, you hear it in this voice.
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
      class="min-w-0 py-3.5 border-b border-[rgba(227,188,91,0.15)]"
      aria-describedby={"choice-#{@name}-note"}
    >
      <legend class="category-choice-legend mb-2.5 float-left w-full">
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

  defp voice_note(voices, slug) do
    case Enum.find(voices, &(&1.slug == slug)) do
      %{description: description} when is_binary(description) -> description
      _voice -> "The voice you hear."
    end
  end
end
