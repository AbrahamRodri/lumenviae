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
      assigns |> assign(:decade, page.decade) |> assign(:page_name, Strand.page_name(page))

    ~H"""
    <section aria-label="The bead you are on" class="flex flex-col">
      <h2 class="sr-only">{@page_name}</h2>
      <Strand.beads sequence={@sequence} screen={@screen} />

      <p
        id="bead-status"
        aria-live="polite"
        aria-atomic="true"
        class="mt-1 text-center kicker text-gilt"
      >
        {status(@screen, @decade)}
      </p>

      <div
        id={"bead-#{@screen.index}"}
        data-screen={@screen.index}
        phx-click={if @screen.kind == :prayer, do: "advance"}
        class={[
          "mt-6 max-w-[62ch] w-full mx-auto rounded-3xl px-1 py-4 motion-safe:animate-[prayer-fade_0.35s_ease-out]",
          @screen.kind == :prayer && "cursor-pointer select-none"
        ]}
      >
        <%= case @screen.kind do %>
          <% :announcement -> %>
            <PrayerText.decade_header decade={@decade} />
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

  # What the bead is, in words: "Hail Mary · 4 of 10", or the mystery
  # announced on the Our Father bead.
  defp status(%{kind: :announcement}, decade), do: decade.label || "The mystery"
  defp status(%{kind: :meditation}, _decade), do: "The meditation"
  defp status(screen, _decade), do: screen.caption
end
