defmodule LumenViaeWeb.Live.Prayers.Prayer.Text do
  @moduledoc """
  A prayer's words as `LumenViaeWeb.Live.Prayers.PrayerText` reads them:
  stanzas of lines, rubrics in red italic, ℣ ℟ ✠ in red, a litany's
  response after its red ℟., a pointed verse's mediant as a red star.

  In Both each line is the Latin with its English: two columns on a wide
  screen, lined up line by line, and the English beneath the Latin,
  smaller and muted, on a phone (`.prayer-text--both` in `app.css`).
  """
  use LumenViaeWeb, :html

  attr :stanzas, :list, required: true
  attr :language, :string, required: true

  def prayer_text(assigns) do
    ~H"""
    <div
      class={["prayer-text", @language == "both" && "prayer-text--both"]}
      lang={if(@language == "latin", do: "la")}
      data-role="prayer-text"
    >
      <div :for={stanza <- @stanzas} class={["prayer-stanza", "prayer-stanza--#{stanza.kind}"]}>
        <div :if={stanza.kind == :rule} aria-hidden="true">
          <.sacred_divider class="max-w-[120px]" />
        </div>
        <p
          :for={line <- stanza.lines}
          :if={stanza.kind != :rule}
          class={["prayer-line", line.secondary && "prayer-line--paired"]}
        >
          <span class="prayer-line__primary" lang={line.secondary && "la"}>
            <.part part={line.primary} />
          </span>
          <span :if={line.secondary} class="prayer-line__secondary" lang="en">
            <.part part={line.secondary} />
          </span>
        </p>
      </div>
    </div>
    """
  end

  attr :part, :any, required: true

  defp part(%{part: {:rubric, runs}} = assigns) do
    assigns = assign(assigns, :runs, runs)

    ~H"""
    <span class="prayer-rubric" data-role="rubric">{runs(@runs)}</span>
    """
  end

  defp part(%{part: {:litany, invocation, response}} = assigns) do
    assigns = assign(assigns, invocation: invocation, response: response)

    ~H"""
    {runs(@invocation)}
    <span class="prayer-litany-response">
      <span class="prayer-glyph" aria-hidden="true">℟.</span> {runs(@response)}
    </span>
    """
  end

  defp part(%{part: {:pointed, first, second}} = assigns) do
    assigns = assign(assigns, first: first, second: second)

    ~H"""
    {runs(@first)} <span class="prayer-glyph" aria-hidden="true">*</span>
    {runs(@second)}
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
       {:glyph, glyph} -> [~s(<span class="prayer-glyph">), escape(glyph), "</span>"]
       {:text, text} -> escape(text)
     end)}
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
