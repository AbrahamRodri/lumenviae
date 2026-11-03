defmodule LumenViaeWeb.Live.Hours.Hour.Section do
  @moduledoc """
  One section of an hour as `LumenViaeWeb.Live.Hours.OfficeText` reads it:
  its name over the text in gilt capitals, the rubric note in red italic,
  and the lines with ℣ ℟ ✠ in red. Set in the Prayer Book's `book-*`
  reading classes, so an hour and a prayer read alike: in Both each line
  is the Latin with its English in quiet italic, side by side from 768px
  and beneath it on a phone; two sides that do not pair line for line
  stand as two blocks.
  """
  use LumenViaeWeb, :html

  attr :section, :map, required: true

  def office_section(assigns) do
    ~H"""
    <section
      id={@section.id}
      class="hours-section"
      aria-labelledby={@section.name && "#{@section.id}-name"}
      data-role="office-section"
      data-rail-section={@section.name && @section.id}
    >
      <h2 :if={@section.name} id={"#{@section.id}-name"} class="hours-section__name">
        {@section.name}
      </h2>
      <p :if={@section.note} class="book-rubric hours-section__note" data-role="note">
        {@section.note}
      </p>
      <.body body={@section.body} />
    </section>
    """
  end

  attr :body, :any, required: true

  defp body(%{body: {:single, side, lines}} = assigns) do
    assigns = assign(assigns, side: side, lines: lines)

    ~H"""
    <div class="book-text hours-text" lang={lang(@side)}>
      <p :for={line <- @lines} class="book-line">
        <span class="book-line__primary">{runs(line)}</span>
      </p>
    </div>
    """
  end

  defp body(%{body: {:paired, pairs}} = assigns) do
    assigns = assign(assigns, :pairs, pairs)

    ~H"""
    <div class="book-text book-text--both hours-text" data-role="paired">
      <p :for={{latin, english} <- @pairs} class="book-line book-line--paired">
        <span class="book-line__primary" lang="la">{runs(latin)}</span>
        <span class="book-line__secondary" lang="en">{runs(english)}</span>
      </p>
    </div>
    """
  end

  defp body(%{body: {:blocks, latin, english}} = assigns) do
    assigns = assign(assigns, latin: latin, english: english)

    ~H"""
    <div class="hours-blocks" data-role="blocks">
      <div class="book-text hours-text" lang="la">
        <p :for={line <- @latin} class="book-line">
          <span class="book-line__primary">{runs(line)}</span>
        </p>
      </div>
      <div class="book-text hours-text hours-text--secondary">
        <p :for={line <- @english} class="book-line">
          <span class="book-line__primary">{runs(line)}</span>
        </p>
      </div>
    </div>
    """
  end

  defp lang(:latin), do: "la"
  defp lang(:english), do: nil

  # One run of markup, not a template: a template's line breaks would put
  # a space between a glyph and the stop after it ("℟ .").
  defp runs(runs) do
    {:safe,
     Enum.map(runs, fn
       {:glyph, glyph} -> [~s(<span class="book-glyph">), escape(glyph), "</span>"]
       {:note, note} -> [~s( <span class="book-rubric">), escape(note), "</span>"]
       {:text, text} -> escape(text)
     end)}
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
