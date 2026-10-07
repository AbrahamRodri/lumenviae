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
  attr :size, :string, default: "full", values: ~w(full quiet)
  attr :language, :string, default: "en", doc: "the language the prayer is set in"

  def prayer(assigns) do
    assigns = assign(assigns, :lines, Sequence.prayer_lines(assigns.prayer_id, assigns.language))

    ~H"""
    <div lang={@language}>
      <h3 :if={@title} class="kicker text-gilt mb-3">
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
  attr :chaplet, :boolean, default: false

  def announcement(assigns) do
    ~H"""
    <header class="text-center">
      <p
        :if={@decade.label}
        class="kicker"
      >
        {@decade.label}
      </p>
      <h2 class="mt-2 font-display font-semibold text-3xl md:text-4xl text-gilt leading-snug">
        {@decade.name}
      </h2>
      <p :if={@decade.fruit} class="mt-3 font-garamond text-lg text-ink-muted">
        <span class="kicker">
          Ask for
        </span>
        <span class="text-ink-muted" aria-hidden="true">&middot;</span>
        <span class="sr-only">:</span>
        {@decade.fruit}
      </p>
      <p
        :if={@decade.scripture_reference}
        class="mt-2 kicker"
      >
        {@decade.scripture_reference}
      </p>
    </header>
    """
  end

  attr :meditation, :map, required: true
  attr :audio_url, :string, default: nil
  attr :pray_aloud, :boolean, default: false

  @doc """
  A set's meditation, on its reading page: vellum, or night if the reader
  chose it (`.reading-page` in app.css). The audio stays on the night above
  the page.
  """
  def meditation(assigns) do
    ~H"""
    <div class="max-w-[62ch] mx-auto">
      <div :if={!@pray_aloud} class="flex justify-center mb-6 empty:hidden">
        <.audio_player audio_url={@audio_url} />
        <p
          :if={@meditation.audio_url && !@audio_url}
          class="font-garamond text-base text-ink-muted border border-night-border rounded-full px-4 py-2"
          title="This meditation has audio, but the audio URL could not be generated. Check that AWS credentials are configured on the server."
        >
          Audio unavailable
        </p>
      </div>

      <article class="reading-page">
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
    <div class="font-garamond prayer-text space-y-[0.9em]">
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

  attr :key, :string, required: true, doc: "the mystery's key, such as \"joyful_1\""

  @doc """
  The mystery's woodcut above its announcement, unless the reader turned
  images off in the settings pane (`.prayer-plate` in app.css).
  """
  def plate(assigns) do
    ~H"""
    <div class="prayer-plate mb-6">
      <WoodcutPlate.woodcut_plate
        key={@key}
        size={:sm}
        caption={false}
        class="!max-w-36 sm:!max-w-44"
      />
    </div>
    """
  end
end
