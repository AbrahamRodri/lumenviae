defmodule LumenViaeWeb.Live.Pray.PrayerText do
  @moduledoc """
  The words of the prayer page: a prayer, a Scriptural Rosary verse, a
  mystery's announcement and a set's meditation.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.WoodcutPlate
  alias LumenViaeWeb.Live.Pray.Sequence

  attr :prayer_id, :string, required: true
  attr :title, :string, default: nil, doc: "shown above the words; nil for none"

  attr :title_shown, :boolean,
    default: true,
    doc:
      "false where the line above already names the prayer: the title is then for screen readers"

  attr :size, :string, default: "full", values: ~w(full quiet)
  attr :language, :string, default: "en", doc: "the language the prayer is set in"

  def prayer(assigns) do
    assigns = assign(assigns, :lines, Sequence.prayer_lines(assigns.prayer_id, assigns.language))

    ~H"""
    <div lang={@language}>
      <h3 :if={@title} class={if @title_shown, do: "kicker text-gilt mb-3", else: "sr-only"}>
        {@title}
      </h3>
      <div class={[
        "font-garamond",
        if(@size == "full",
          do: "prayer-text text-ink-light",
          else: "prayer-text-quiet text-ink-muted"
        )
      ]}>
        <%= for line <- @lines do %>
          <p :if={elem(line, 0) == :rubric} class="italic text-ink-muted text-[0.9em] my-2">
            {elem(line, 1)}
          </p>
          <p :if={elem(line, 0) == :line}>{elem(line, 1)}</p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :verse, :map, required: true

  def verse(assigns) do
    ~H"""
    <figure class="prayer-verse">
      <blockquote class="font-garamond prayer-text text-ink-light">
        {@verse.text}
      </blockquote>
      <figcaption
        :if={@verse.reference}
        class="mt-3 kicker"
      >
        {@verse.reference}
      </figcaption>
    </figure>
    """
  end

  attr :decade, :map, required: true

  @doc """
  A decade's header: the mystery's woodcut beside its announcement, so
  the words of the decade start on the first screen of a phone. With the
  images turned off the announcement takes the whole width.
  """
  def decade_header(assigns) do
    ~H"""
    <header class="flex items-center gap-4 sm:gap-6 max-w-[62ch] mx-auto">
      <div class="prayer-plate w-[5.5rem] sm:w-32 shrink-0">
        <WoodcutPlate.woodcut_plate
          key={@decade.key}
          size={:sm}
          caption={false}
          class="prayer-plate-mat"
        />
      </div>
      <div class="min-w-0">
        <p :if={@decade.label} class="kicker">
          {@decade.label}
        </p>
        <h2 class="mt-1 font-display !font-normal text-[1.625rem] md:text-4xl text-ink-light leading-[1.15]">
          {@decade.name}
        </h2>
        <p
          :if={@decade.fruit || @decade.scripture_reference}
          class="mt-1.5 font-garamond text-base md:text-lg text-ink-muted leading-snug"
        >
          <span :if={@decade.fruit} class="italic">Ask for {@decade.fruit}</span>
          <span :if={@decade.fruit && @decade.scripture_reference} aria-hidden="true">
            &middot;
          </span>
          <span :if={@decade.scripture_reference} class="whitespace-nowrap">
            {@decade.scripture_reference}
          </span>
        </p>
      </div>
    </header>
    """
  end

  attr :meditation, :map, required: true
  attr :audio_url, :string, default: nil
  attr :pray_aloud, :boolean, default: false

  @doc """
  A set's meditation, on its reading page: night, or vellum if the reader
  chose it (`.reading-page` in app.css). Its recording is played from the
  top of the page, in the page's own colours.
  """
  def meditation(assigns) do
    ~H"""
    <div class="max-w-[62ch] mx-auto">
      <article class="reading-page">
        <div :if={!@pray_aloud && @audio_url} class="flex items-center gap-3 mb-4">
          <.audio_player audio_url={@audio_url} size="reading" />
          <p class="reading-page__meta font-display text-xs tracking-[0.16em] uppercase">
            Listen to the meditation
          </p>
        </div>
        <p
          :if={!@pray_aloud && @meditation.audio_url && !@audio_url}
          class="reading-page__meta font-garamond text-base mb-4"
          title="This meditation has audio, but the audio URL could not be generated. Check that AWS credentials are configured on the server."
        >
          Audio unavailable
        </p>

        <h3
          :if={@meditation.title}
          class="reading-page__title font-display font-semibold text-2xl md:text-3xl mb-4 text-center"
        >
          {@meditation.title}
        </h3>

        <.meditation_text content={@meditation.content} />

        <footer
          :if={@meditation.author || @meditation.source}
          class="reading-page__meta mt-6 pt-4 border-t text-right font-garamond italic"
        >
          <p :if={@meditation.author}>&mdash; {@meditation.author}</p>
          <p :if={@meditation.source} class="not-italic text-base mt-1">
            {@meditation.source}
          </p>
        </footer>
      </article>
    </div>
    """
  end

  attr :content, :string, default: nil

  @doc """
  A meditation's words as the curation guide writes them
  (docs/MEDITATION_CURATION_GUIDE.md): a blank line starts a new paragraph,
  and a single newline is a line break inside one.
  """
  def meditation_text(assigns) do
    assigns = assign(assigns, :paragraphs, paragraphs(assigns.content))

    ~H"""
    <div class="meditation-text font-garamond prayer-text space-y-[0.9em]">
      <p :for={lines <- @paragraphs}>
        <%= for {line, index} <- Enum.with_index(lines) do %>
          <br :if={index > 0} />{line}
        <% end %>
      </p>
    </div>
    """
  end

  @doc """
  Splits meditation content into paragraphs, each a list of its lines.
  Blank lines (or lines of only spaces) separate paragraphs; the lines keep
  their words and lose stray indentation.

      paragraphs("a\\nb\\n\\nc") #=> [["a", "b"], ["c"]]
  """
  def paragraphs(nil), do: []

  def paragraphs(content) when is_binary(content) do
    content
    |> String.replace("\r\n", "\n")
    |> String.split(~r/\n[ \t]*\n/)
    |> Enum.map(fn paragraph ->
      paragraph
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    end)
    |> Enum.reject(&(&1 == []))
  end
end
