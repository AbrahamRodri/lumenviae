defmodule LumenViaeWeb.Live.Pray.BeadScreen do
  @moduledoc """
  One prayer at a time, as the voice says it: the strand with the bead
  under the hand lit, what is said on it in words, and the words
  themselves, every prayer at the one size. Where the recording is timed
  (`timings`), the words carry the line each belongs to, and the
  SpokenRosary hook lights the line being read. A bead of plain prayer is
  itself the way to the next one: tap the words, press Space, or swipe.
  The words and the strand carry `prayer-words`, which the reader's
  "Show Words and Beads" choice hides (app.css); the bead's name stays.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Pray.{PrayerText, Sequence, Strand}

  attr :sequence, :map, required: true
  attr :screen, :map, required: true

  attr :timings, :map,
    default: %{},
    doc: "the timed lines of what is heard on this screen, by kind (:prayer, :verse, :meditation)"

  attr :show_meditation, :boolean, default: false
  attr :language, :string, default: "en"

  def bead_screen(assigns) do
    page = Sequence.page(assigns.sequence, assigns.screen.page)

    assigns =
      assigns
      |> assign(:decade, page.decade)
      |> assign(:page_name, Strand.page_name(page))
      |> assign(:part, part_name(page))
      |> assign(:place, place(page, assigns.sequence))

    ~H"""
    <section aria-label="The bead you are on" class="flex flex-col">
      <h2 class="sr-only">{@page_name}</h2>

      <%!-- The title block, as the app's: the part's name, where it falls,
           then the step, left-aligned with the words. It is the same on
           every step of a part, so moving a bead never shifts the page. --%>
      <div id="bead-title" class="mt-5 max-w-[62ch] w-full mx-auto px-1">
        <p
          aria-hidden="true"
          class="font-display !font-normal text-[1.75rem] lg:text-[2.25rem] text-ink-light leading-[1.15] text-balance"
        >
          {@part}
        </p>
        <p class="mt-1 font-garamond italic text-base md:text-lg text-ink-muted leading-snug">
          {@place}
        </p>
        <p
          id="bead-status"
          aria-live="polite"
          aria-atomic="true"
          class="mt-2 font-display !font-normal text-[0.8rem] uppercase tracking-[0.18em] text-ink-light leading-snug"
        >
          {status(@screen, @decade)}
        </p>
      </div>

      <%!-- The words, with the bead rail down their right side, as the app's. --%>
      <div class="mt-6 flex items-start gap-2 sm:gap-4 max-w-[calc(62ch+3.75rem)] w-full mx-auto">
        <div
          id={"bead-#{@screen.index}"}
          data-screen={@screen.index}
          phx-click={if @screen.kind == :prayer, do: "advance"}
          class={[
            "flex-1 min-w-0 rounded-3xl px-1 py-4 motion-safe:animate-[prayer-fade_0.35s_ease-out]",
            @screen.kind == :prayer && "cursor-pointer select-none"
          ]}
        >
          <%= case @screen.kind do %>
            <% :announcement -> %>
              <PrayerText.decade_header decade={@decade} name_shown={false} />
              <div
                :if={@decade.meditation && @sequence.form == "scriptural"}
                class="prayer-words mt-8"
              >
                <.meditation_toggle meditation={@decade.meditation} open={@show_meditation} />
              </div>
            <% :meditation -> %>
              <div :if={@decade && @decade.meditation} class="prayer-words">
                <PrayerText.meditation meditation={@decade.meditation} lines={@timings[:meditation]} />
              </div>
            <% :prayer -> %>
              <div :if={@screen.verse} class="prayer-words mb-8 text-center">
                <PrayerText.verse verse={@screen.verse} lines={@timings[:verse]} />
              </div>
              <div class="prayer-words">
                <PrayerText.prayer
                  prayer_id={@screen.prayer_id}
                  title={Sequence.prayer_title(@screen.prayer_id, @language)}
                  title_shown={false}
                  language={@language}
                  lines={@timings[:prayer]}
                />
              </div>
          <% end %>
        </div>
        <div class="sticky top-4 shrink-0 self-start pt-4">
          <Strand.beads sequence={@sequence} screen={@screen} />
        </div>
      </div>
    </section>
    """
  end

  attr :meditation, :map, required: true
  attr :open, :boolean, default: false

  # The set's meditation, folded away under a Scriptural Rosary's mystery:
  # the Scriptural Rosary's voice reads verses, not the meditation, so it
  # is read on the page and never lit.
  defp meditation_toggle(assigns) do
    ~H"""
    <div class="max-w-[62ch] mx-auto text-center">
      <button
        type="button"
        phx-click="toggle_meditation"
        aria-expanded={to_string(@open)}
        aria-controls="scriptural-meditation"
        class="btn-outline-gold !py-2.5 min-h-11"
      >
        {if @open, do: "Hide the meditation", else: "Read the meditation"}
      </button>
      <div :if={@open} id="scriptural-meditation" class="mt-6 text-left">
        <PrayerText.meditation meditation={@meditation} />
      </div>
    </div>
    """
  end

  # The part being prayed, by its name, as the app titles it.
  defp part_name(%{kind: :opening}), do: "The Opening Prayers"
  defp part_name(%{kind: :closing}), do: "The Closing Prayers"
  defp part_name(%{decade: decade}), do: decade.name || decade.label

  # Where the part falls in the Rosary: its mysteries, or the Seven
  # Sorrows' sorrows.
  defp place(page, sequence), do: place(page, unit(sequence), length(sequence.decades))

  defp place(%{kind: :opening}, unit, _count), do: "Before the first #{unit}"
  defp place(%{kind: :closing}, unit, _count), do: "After the last #{unit}"
  defp place(%{index: index}, unit, count), do: "#{String.capitalize(unit)} #{index} of #{count}"

  defp unit(%{category: "seven_sorrows"}), do: "sorrow"
  defp unit(_sequence), do: "mystery"

  # What the bead is, in words: "Hail Mary · 4 of 10", or the mystery
  # announced on the Our Father bead.
  defp status(%{kind: :announcement}, decade), do: decade.label || "The mystery"
  defp status(%{kind: :meditation}, _decade), do: "The meditation"
  defp status(screen, _decade), do: screen.caption
end
