defmodule LumenViaeWeb.Live.Pray.PageView do
  @moduledoc """
  Counting "On My Rosary": a page at a time. The opening and closing
  prayers read whole; a decade is its announcement, its meditation or its
  verses, and the decade's prayers to say on the beads.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Pray.{PrayerText, Sequence}

  attr :sequence, :map, required: true
  attr :page, :map, required: true
  attr :audio_url, :string, default: nil
  attr :pray_aloud, :boolean, default: false
  attr :show_meditation, :boolean, default: false
  attr :language, :string, default: "en"

  def page_view(%{page: %{kind: :decade}} = assigns) do
    assigns =
      assigns
      |> assign(:decade, assigns.page.decade)
      |> assign(:verses, Enum.filter(assigns.page.screens, & &1.verse))

    ~H"""
    <section aria-labelledby={"page-title-#{@page.index}"} class="space-y-8">
      <div id={"page-title-#{@page.index}"}>
        <PrayerText.announcement decade={@decade} chaplet={@sequence.chaplet?} />
      </div>

      <.sacred_divider class="!my-6" />

      <PrayerText.meditation
        :if={@decade.meditation && @sequence.form == "meditation"}
        meditation={@decade.meditation}
        audio_url={@audio_url}
        pray_aloud={@pray_aloud}
      />

      <ol
        :if={@verses != []}
        class="space-y-6 max-w-[62ch] mx-auto"
        aria-label="The verses, one before each Hail Mary"
      >
        <li :for={screen <- @verses} class="flex gap-4">
          <span class="font-cinzel text-gold text-sm pt-1 w-6 shrink-0 text-right" aria-hidden="true">
            {screen.bead}
          </span>
          <div class="flex-1">
            <PrayerText.verse verse={screen.verse} />
            <p class="mt-1 font-cinzel text-xs tracking-[0.22em] uppercase text-gold-light/60">
              {screen.caption}
            </p>
          </div>
        </li>
      </ol>

      <.meditation_toggle
        :if={@decade.meditation && @sequence.form == "scriptural"}
        meditation={@decade.meditation}
        audio_url={@audio_url}
        pray_aloud={@pray_aloud}
        open={@show_meditation}
      />

      <div class="max-w-[62ch] mx-auto rounded-2xl border border-gold/20 bg-navy-dark/40 px-5 py-5">
        <h3 class="font-cinzel text-xs tracking-[0.22em] uppercase text-gold mb-3">
          On your rosary
        </h3>
        <ol class="font-garamond text-lg text-cream/85 space-y-1">
          <li>The Our Father, on the large bead</li>
          <li>{hail_marys_line(@sequence)}</li>
          <li>
            {if @sequence.chaplet?, do: "The Glory Be", else: "The Glory Be and the Fatima Prayer"}
          </li>
        </ol>
        <details class="mt-4 group">
          <summary class="cursor-pointer min-h-11 flex items-center font-cinzel text-xs tracking-[0.22em] uppercase text-gold-light/80 hover:text-gold rounded">
            Show the words
          </summary>
          <div class="mt-4 space-y-6">
            <PrayerText.prayer
              :for={id <- decade_prayers(@sequence)}
              prayer_id={id}
              title={Sequence.prayer_title(id, @language)}
              size="quiet"
              language={@language}
            />
          </div>
        </details>
      </div>
    </section>
    """
  end

  def page_view(assigns) do
    assigns = assign(assigns, :blocks, Sequence.blocks(assigns.page))

    ~H"""
    <section aria-labelledby={"page-title-#{@page.index}"} class="max-w-[62ch] mx-auto">
      <h2
        id={"page-title-#{@page.index}"}
        class="font-cinzel text-2xl md:text-3xl text-gold text-center"
      >
        {if @page.kind == :opening, do: "The Opening Prayers", else: "The Closing Prayers"}
      </h2>
      <.sacred_divider class="!my-6" />
      <ol class="space-y-10">
        <li :for={block <- @blocks}>
          <p
            :if={caption_line(block)}
            class="font-cinzel text-xs tracking-[0.22em] uppercase text-gold-light/70 mb-1"
          >
            {caption_line(block)}
          </p>
          <PrayerText.prayer
            prayer_id={hd(block).prayer_id}
            title={block_title(block, @language)}
            language={@language}
          />
        </li>
      </ol>
    </section>
    """
  end

  attr :meditation, :map, required: true
  attr :audio_url, :string, default: nil
  attr :pray_aloud, :boolean, default: false
  attr :open, :boolean, default: false

  @doc "The set's meditation, folded away beneath a Scriptural Rosary's verses."
  def meditation_toggle(assigns) do
    ~H"""
    <div class="max-w-[62ch] mx-auto text-center">
      <button
        type="button"
        phx-click="toggle_meditation"
        aria-expanded={to_string(@open)}
        aria-controls="scriptural-meditation"
        class="btn-outline-gold text-gold-light !py-2.5 min-h-11"
      >
        {if @open, do: "Hide the meditation", else: "Read the meditation"}
      </button>
      <div :if={@open} id="scriptural-meditation" class="mt-6 text-left">
        <PrayerText.meditation
          meditation={@meditation}
          audio_url={@audio_url}
          pray_aloud={@pray_aloud}
        />
      </div>
    </div>
    """
  end

  defp hail_marys_line(sequence) do
    count = if sequence.hail_marys == 7, do: "Seven", else: "Ten"
    "#{count} Hail Marys, one on each small bead"
  end

  defp decade_prayers(%{chaplet?: true}), do: ~w(our_father hail_mary glory_be)
  defp decade_prayers(_sequence), do: ~w(our_father hail_mary glory_be fatima_prayer)

  # A run of one prayer said several times is shown once, under its
  # captions; a prayer whose caption is only its name needs none.
  defp caption_line([screen]) do
    if screen.caption == Sequence.prayer_title(screen.prayer_id), do: nil, else: screen.caption
  end

  defp caption_line(block), do: Enum.map_join(block, " · ", & &1.caption)

  defp block_title([screen], language), do: Sequence.prayer_title(screen.prayer_id, language)

  defp block_title([screen | _] = block, language),
    do: "#{Sequence.prayer_title(screen.prayer_id, language)} (#{length(block)} times)"
end
