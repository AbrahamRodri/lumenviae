defmodule LumenViaeWeb.Live.Missal.Section do
  @moduledoc """
  One part of the Mass as `LumenViaeWeb.Live.Missal.MissalText` reads it,
  the iOS app's `MissalReaderSectionView`: the posture kept through it
  between two fading rules, the propers' gold diamond, the plain name in
  gilt capitals with the Latin name small and dim beside it, then its
  passages: citations as small engraved capitals in dim gold, the lines
  with ℣ ℟ ✠ in red, a rubric of the Order of Mass in quiet italic. In
  Both each line is the Latin with its English in quiet italic, side by
  side from 768px and beneath it on a phone (the Prayer Book's `book-*`
  classes, as an hour of the Office is set); two sides that do not pair
  line for line stand as two blocks.
  """
  use LumenViaeWeb, :html

  attr :section, :map, required: true

  def missal_section(assigns) do
    ~H"""
    <section
      id={@section.id}
      class="hours-section missal-section"
      aria-labelledby={"#{@section.id}-name"}
      data-role="missal-section"
      data-rail-section={@section.id}
    >
      <p :if={@section.posture} class="missal-posture" data-role="posture">
        {@section.posture}
      </p>
      <h2 id={"#{@section.id}-name"} class="missal-section__name">
        <span :if={@section.proper?} class="missal-diamond" data-role="proper" aria-hidden="true"></span>
        <span>{@section.name}</span>
        <span :if={@section.latin} class="missal-section__latin" lang="la">{@section.latin}</span>
      </h2>
      <div class="missal-passages">
        <.passage :for={passage <- @section.passages} passage={passage} />
      </div>
    </section>
    """
  end

  attr :passage, :any, required: true

  defp passage(%{passage: {:note, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <p class="missal-note" data-role="rubric">{@text}</p>
    """
  end

  defp passage(%{passage: {:single, side, items}} = assigns) do
    assigns = assign(assigns, side: side, items: items)

    ~H"""
    <div class="book-text missal-text" lang={lang(@side)}>
      <.item :for={item <- @items} item={item} />
    </div>
    """
  end

  defp passage(%{passage: {:paired, items}} = assigns) do
    assigns = assign(assigns, :items, items)

    ~H"""
    <div class="book-text book-text--both missal-text" data-role="paired">
      <.item :for={item <- @items} item={item} />
    </div>
    """
  end

  defp passage(%{passage: {:blocks, latin, english}} = assigns) do
    assigns = assign(assigns, latin: latin, english: english)

    ~H"""
    <div class="hours-blocks" data-role="blocks">
      <div class="book-text missal-text" lang="la">
        <.item :for={item <- @latin} item={item} />
      </div>
      <div class="book-text missal-text hours-text--secondary">
        <.item :for={item <- @english} item={item} />
      </div>
    </div>
    """
  end

  attr :item, :any, required: true

  defp item(%{item: {:citation, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <p class="missal-citation" data-role="citation">{@text}</p>
    """
  end

  defp item(%{item: {kind, runs}} = assigns) when kind in [:line, :versal] do
    assigns = assign(assigns, runs: runs, versal?: kind == :versal)

    ~H"""
    <p class={["missal-line", @versal? && "missal-line--versal"]}>{runs(@runs)}</p>
    """
  end

  defp item(%{item: {kind, latin, english}} = assigns) when kind in [:pair, :versal_pair] do
    assigns = assign(assigns, latin: latin, english: english, versal?: kind == :versal_pair)

    ~H"""
    <p class={["book-line book-line--paired missal-pair", @versal? && "missal-line--versal"]}>
      <span class="book-line__primary" lang="la">{runs(@latin)}</span>
      <span class="book-line__secondary" lang="en">{runs(@english)}</span>
    </p>
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
       {_kind, text} -> escape(text)
     end)}
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
