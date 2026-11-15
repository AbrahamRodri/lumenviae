defmodule LumenViaeWeb.Live.Prayers.Prayer.Text do
  @moduledoc """
  A prayer's words as `LumenViaeWeb.Live.Prayers.PrayerText` reads them,
  set as the app's `ReadingText` sets them: stanzas of lines, rubrics in
  red italic, ℣ ℟ ✠ in red, a litany's response after its red ℟., a
  psalm verse broken at its mediant (the red star ends the first half,
  the second hangs in on a line of its own), and a long prose prayer
  opening on a gilt versal.

  In Both each line is the English with its Latin in quiet italic, as the
  app's Prayer Book sets it: on a phone the Latin beneath each English
  line, stepped in; on a wide screen the two side by side, line by line
  (`.book-text--both` in `app.css`). The classes are `book-*`, apart from
  the Rosary page's `.prayer-text`.
  """
  use LumenViaeWeb, :html

  # The app sets a versal only on an opening at least this long
  # (DropCapText.minimumLength).
  @versal_length 80

  attr :stanzas, :list, required: true
  attr :language, :string, required: true

  attr :today_mark, :string,
    default: nil,
    doc: "a heading to mark Today (`Book.season_mark/2`): its stanza takes the id `today`"

  def prayer_text(assigns) do
    assigns = assign(assigns, :versal?, versal?(assigns.stanzas))

    ~H"""
    <div
      class={["book-text", @language == "both" && "book-text--both"]}
      lang={if(@language == "latin", do: "la")}
      data-role="prayer-text"
    >
      <div
        :for={{stanza, i} <- Enum.with_index(@stanzas)}
        id={if(today?(stanza, @today_mark), do: "today")}
        class={[
          "book-stanza",
          "book-stanza--#{stanza.kind}",
          today?(stanza, @today_mark) && "scroll-mt-24",
          (i == 0 and @versal?) && "book-stanza--versal"
        ]}
      >
        <p :if={today?(stanza, @today_mark)} class="kicker !text-gilt" data-role="today">
          Today
        </p>
        <div :if={stanza.kind == :rule} aria-hidden="true">
          <.sacred_divider class="max-w-[120px]" />
        </div>
        <p
          :for={line <- stanza.lines}
          :if={stanza.kind != :rule}
          class={[
            "book-line",
            line.secondary && "book-line--paired",
            flush?(stanza, line) && "book-line--flush"
          ]}
        >
          <span class="book-line__primary">
            <.part part={line.primary} />
          </span>
          <span :if={line.secondary} class="book-line__secondary" lang="la">
            <.part part={line.secondary} />
          </span>
        </p>
      </div>
    </div>
    """
  end

  # The stanza that is the marked heading alone, as the text prints it.
  defp today?(_stanza, nil), do: false

  defp today?(%{lines: [%{primary: {:rubric, runs}}]}, mark),
    do: runs |> Enum.map_join(&elem(&1, 1)) |> String.trim() == mark

  defp today?(_stanza, _mark), do: false

  # A versal opens the first stanza when it is one long paragraph, as the
  # app's DropCapText does.
  defp versal?([%{kind: :prose, lines: [%{primary: {:text, runs}}]} | _]),
    do: runs |> Enum.map_join(&elem(&1, 1)) |> String.length() >= @versal_length

  defp versal?(_stanzas), do: false

  # Only a line of verse hangs from its first word: a lone line is a
  # paragraph, and a rubric a direction, so a wrapped one sets flush.
  defp flush?(%{lines: [_only]}, _line), do: true
  defp flush?(_stanza, %{primary: {:rubric, _runs}}), do: true
  defp flush?(_stanza, _line), do: false

  attr :part, :any, required: true

  defp part(%{part: {:rubric, runs}} = assigns) do
    assigns = assign(assigns, :runs, runs)

    ~H"""
    <span class="book-rubric" data-role="rubric">{runs(@runs)}</span>
    """
  end

  defp part(%{part: {:litany, invocation, response}} = assigns) do
    assigns = assign(assigns, invocation: invocation, response: response)

    ~H"""
    {runs(@invocation)}
    <span class="book-litany-response">
      <span class="book-glyph" aria-hidden="true">℟.</span> {runs(@response)}
    </span>
    """
  end

  defp part(%{part: {:pointed, first, second}} = assigns) do
    assigns = assign(assigns, first: first, second: second)

    ~H"""
    <span class="book-verse" data-role="mediant">{runs(@first)}<span
      class="book-glyph"
      aria-hidden="true"
    > *</span></span><span class="book-verse book-verse--second">{runs(@second)}</span>
    """
  end

  defp part(%{part: {:text, runs}} = assigns) do
    assigns = assign(assigns, :runs, runs)

    ~H"""
    {runs(@runs)}
    """
  end

  # Built as one run of markup, not a template: a template's line breaks
  # would put a space between a glyph and the stop after it ("℟ .").
  defp runs(runs) do
    {:safe,
     Enum.map(runs, fn
       {:glyph, glyph} -> [~s(<span class="book-glyph">), escape(glyph), "</span>"]
       {:text, text} -> escape(text)
     end)}
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
