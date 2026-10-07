defmodule LumenViaeWeb.Live.Pray.BeadScreen do
  @moduledoc """
  Counting "On the Screen": one bead at a time. The strand with the bead
  under the hand lit, what is said on it in words, and the words
  themselves. A bead of plain prayer is itself the way to the next one:
  tap the words, press Space, or swipe.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Pray.{PageView, PrayerText, Sequence, Strand}

  attr :sequence, :map, required: true
  attr :screen, :map, required: true
  attr :audio_url, :string, default: nil
  attr :pray_aloud, :boolean, default: false
  attr :show_meditation, :boolean, default: false

  def bead_screen(assigns) do
    page = Sequence.page(assigns.sequence, assigns.screen.page)
    assigns = assign(assigns, :decade, page.decade)

    ~H"""
    <section aria-label="The bead you are on" class="flex flex-col">
      <Strand.beads sequence={@sequence} screen={@screen} />

      <p
        id="bead-status"
        aria-live="polite"
        aria-atomic="true"
        class="mt-1 text-center font-cinzel text-xs tracking-[0.25em] uppercase text-gold"
      >
        {status(@screen, @decade)}
      </p>

      <div
        id={"bead-#{@screen.index}"}
        phx-click={if @screen.kind == :prayer, do: "advance"}
        class={[
          "mt-6 max-w-[62ch] w-full mx-auto rounded-3xl px-1 py-4 motion-safe:animate-[prayer-fade_0.35s_ease-out]",
          @screen.kind == :prayer && "cursor-pointer select-none"
        ]}
      >
        <%= case @screen.kind do %>
          <% :announcement -> %>
            <PrayerText.announcement decade={@decade} chaplet={@sequence.chaplet?} />
            <div :if={@decade.meditation && @sequence.form == "scriptural"} class="mt-8">
              <PageView.meditation_toggle
                meditation={@decade.meditation}
                audio_url={@audio_url}
                pray_aloud={@pray_aloud}
                open={@show_meditation}
              />
            </div>
          <% :meditation -> %>
            <PrayerText.meditation
              :if={@decade && @decade.meditation}
              meditation={@decade.meditation}
              audio_url={@audio_url}
              pray_aloud={@pray_aloud}
            />
          <% :prayer -> %>
            <div :if={@screen.verse} class="mb-8 text-center">
              <PrayerText.verse verse={@screen.verse} />
            </div>
            <PrayerText.prayer
              prayer_id={@screen.prayer_id}
              title={Sequence.prayer_title(@screen.prayer_id)}
              size={if @screen.verse, do: "quiet", else: "full"}
            />
        <% end %>
      </div>
    </section>
    """
  end

  # What the bead is, in words: "Hail Mary · 4 of 10", or the mystery
  # announced on the Our Father bead.
  defp status(%{kind: :announcement}, decade), do: decade.label || "The mystery"
  defp status(%{kind: :meditation}, _decade), do: "The meditation"
  defp status(screen, _decade), do: screen.caption
end
