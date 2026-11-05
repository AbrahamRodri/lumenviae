defmodule LumenViaeWeb.Live.Pray.PrayerText do
  @moduledoc """
  The words of the prayer page: a prayer, a Scriptural Rosary verse, a
  mystery's announcement and a set's meditation.

  Every prayer is the one size, a long one as large as a short one: the
  page shows the part being read and moves with it, rather than shrinking
  the words to fit. Given the timed lines of what the voice says (`lines`),
  each word is marked with the line it belongs to (`data-line`, inside a
  `data-timed` block named for the kind of words), for the SpokenRosary
  hook to light as it is read; see `LumenViaeWeb.Live.Pray.TimedText`.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.MysteryPainting
  alias LumenViaeWeb.Live.Pray.{Sequence, TimedText}

  attr :prayer_id, :string, required: true
  attr :title, :string, default: nil, doc: "shown above the words; nil for none"

  attr :title_shown, :boolean,
    default: true,
    doc:
      "false where the line above already names the prayer: the title is then for screen readers"

  attr :language, :string, default: "en", doc: "the language the prayer is set in"
  attr :lines, :list, default: nil, doc: "the timed lines of its recording, or nil"

  def prayer(assigns) do
    shown = Sequence.prayer_lines(assigns.prayer_id, assigns.language)
    words = for {:line, text} <- shown, do: text
    segments = TimedText.segments(words, assigns.lines)

    assigns =
      assigns
      |> assign(:shown, shown)
      |> assign(:timed, segments != nil)
      |> assign(:segments, segments_by_line(shown, segments))

    ~H"""
    <div lang={@language}>
      <h3 :if={@title} class={if @title_shown, do: "kicker text-gilt mb-3", else: "sr-only"}>
        {@title}
      </h3>
      <div class="font-garamond prayer-text text-ink-light" data-timed={@timed && "prayer"}>
        <%= for {line, index} <- Enum.with_index(@shown) do %>
          <p :if={elem(line, 0) == :rubric} class="italic text-ink-muted text-[0.9em] my-2">
            {elem(line, 1)}
          </p>
          <p :if={elem(line, 0) == :line}>
            <.timed segments={@segments[index]} text={elem(line, 1)} />
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :verse, :map, required: true
  attr :lines, :list, default: nil, doc: "the timed lines of its recording, or nil"

  def verse(assigns) do
    segments = TimedText.segments([assigns.verse.text], assigns.lines)
    assigns = assign(assigns, :segments, segments && hd(segments))

    ~H"""
    <figure class="prayer-verse">
      <blockquote class="font-garamond prayer-text text-ink-light" data-timed={@segments && "verse"}>
        <.timed segments={@segments} text={@verse.text} />
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
  A decade's header: the mystery's painting beside its announcement, so
  the words of the decade start on the first screen of a phone. With the
  images turned off the announcement takes the whole width.
  """
  def decade_header(assigns) do
    ~H"""
    <header class="flex items-center gap-4 sm:gap-6 max-w-[62ch] mx-auto">
      <div class="prayer-plate painting-frame w-[5.5rem] sm:w-32 shrink-0">
        <MysteryPainting.picture
          key={@decade.key}
          record={@decade.mystery}
          sizes="(min-width: 640px) 128px, 88px"
          loading="eager"
          class="w-full h-full object-cover"
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
  attr :lines, :list, default: nil, doc: "the timed lines of its narration, or nil"

  @doc """
  A set's meditation, on its reading page: night, or vellum if the reader
  chose it (`.reading-page` in app.css). The player above the page reads
  it; where the narration is timed, the line being read is lit.
  """
  def meditation(assigns) do
    ~H"""
    <div class="max-w-[62ch] mx-auto">
      <article class="reading-page">
        <h3
          :if={@meditation.title}
          class="reading-page__title font-display font-semibold text-2xl md:text-3xl mb-4 text-center"
        >
          {@meditation.title}
        </h3>

        <.meditation_text content={@meditation.content} lines={@lines} />

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
  attr :lines, :list, default: nil, doc: "the timed lines of its narration, or nil"

  @doc """
  A meditation's words as the curation guide writes them
  (docs/MEDITATION_CURATION_GUIDE.md): a blank line starts a new paragraph,
  and a single newline is a line break inside one.
  """
  def meditation_text(assigns) do
    paragraphs = paragraphs(assigns.content)
    segments = TimedText.segments(List.flatten(paragraphs), assigns.lines)

    assigns =
      assigns
      |> assign(:paragraphs, with_segments(paragraphs, segments))
      |> assign(:timed, segments != nil)

    ~H"""
    <div
      class="meditation-text font-garamond prayer-text space-y-[0.9em]"
      data-timed={@timed && "meditation"}
    >
      <p :for={lines <- @paragraphs}>
        <%= for {{line, segments}, index} <- Enum.with_index(lines) do %>
          <br :if={index > 0} /><.timed segments={segments} text={line} />
        <% end %>
      </p>
    </div>
    """
  end

  attr :segments, :list, default: nil
  attr :text, :string, required: true

  # A line of words: as it is, or cut into the timed lines it belongs to.
  defp timed(%{segments: nil} = assigns), do: ~H"{@text}"

  defp timed(assigns) do
    ~H"""
    <%= for {{text, line}, index} <- Enum.with_index(@segments) do %>
      {if index > 0, do: " "}<span :if={line} data-line={line}>{text}</span><span :if={!line}>{text}</span>
    <% end %>
    """
  end

  # The segments of each shown line, by its index among all the lines
  # shown (rubrics included); nil for every line when it is not timed.
  defp segments_by_line(_shown, nil), do: %{}

  defp segments_by_line(shown, segments) do
    shown
    |> Enum.with_index()
    |> Enum.filter(fn {line, _index} -> elem(line, 0) == :line end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.zip(segments)
    |> Map.new()
  end

  defp with_segments(paragraphs, nil),
    do: Enum.map(paragraphs, fn lines -> Enum.map(lines, &{&1, nil}) end)

  defp with_segments(paragraphs, segments) do
    {paragraphs, []} =
      Enum.map_reduce(paragraphs, segments, fn lines, rest ->
        {mine, rest} = Enum.split(rest, length(lines))
        {Enum.zip(lines, mine), rest}
      end)

    paragraphs
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
