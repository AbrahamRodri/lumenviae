defmodule LumenViaeWeb.Live.Prayers.Index.Shelves do
  @moduledoc """
  The Prayers page's shelves, as the app's Prayers tab draws them:
  Everyday Prayers as rows with a painting, Prayers to Mary as painted
  cards (a grid here, where the app scrolls them sideways), and All
  Topics as a ruled ledger, each chapter with its line and its count.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.MysteryPainting
  alias LumenViaeWeb.Live.Prayers.Book

  attr :prayers, :list, required: true

  def everyday(assigns) do
    ~H"""
    <section aria-labelledby="everyday-heading">
      <.shelf_heading
        id="everyday-heading"
        title="Everyday Prayers"
        to={Book.chapter_path(Book.first_chapter_id())}
      />
      <ul class="row-list">
        <li :for={prayer <- @prayers}>
          <.link navigate={Book.prayer_path(prayer.id)} class="row-link" data-role="everyday-row">
            <span class="arch-thumb w-14 h-14" aria-hidden="true">
              <.painting
                painting={Book.prayer_painting(prayer.id)}
                sizes="56px"
                class="w-full h-full object-cover"
              />
            </span>
            <span class="flex-1 min-w-0">
              <span class="row-title">{Book.list_name(prayer)}</span>
              <span
                :if={Book.second_title(prayer)}
                class="block italic text-base text-ink-muted leading-snug"
              >
                {Book.second_title(prayer)}
              </span>
            </span>
            <span class="hero-chevron-right size-5 row-chevron" aria-hidden="true" />
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :cards, :list, required: true

  def prayers_to_mary(assigns) do
    ~H"""
    <section aria-labelledby="mary-heading">
      <.shelf_heading
        id="mary-heading"
        title="Prayers to Mary"
        to={Book.chapter_path(Book.our_lady_chapter_id())}
      />
      <ul class="grid grid-cols-2 sm:grid-cols-3 gap-3 sm:gap-4">
        <li :for={card <- @cards} class={card.seasonal? && "col-span-2 sm:col-span-1"}>
          <.link
            navigate={Book.prayer_path(card.prayer.id)}
            class={["paint-tile prayers-card", card.seasonal? && "paint-tile--today"]}
            data-role={if card.seasonal?, do: "seasonal-card", else: "marian-card"}
          >
            <.painting
              painting={card.painting}
              sizes="(min-width: 1024px) 180px, (min-width: 640px) 30vw, 46vw"
              class="paint-tile__image"
            />
            <span class="paint-tile__words">
              <h3 class="paint-tile__title">{Book.list_name(card.prayer)}</h3>
              <span class="paint-tile__line">{card.note}</span>
            </span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :chapters, :list, required: true

  def all_topics(assigns) do
    ~H"""
    <section aria-labelledby="topics-heading" class="min-w-0">
      <%!-- As tall as the other shelves' headings, which carry a link. --%>
      <h2 id="topics-heading" class="section-label min-h-11 !mb-1">All Topics</h2>
      <ol class="row-list">
        <li :for={chapter <- @chapters}>
          <.link navigate={Book.chapter_path(chapter.id)} class="row-link" data-role="topic-row">
            <span class="prayers-numeral" aria-hidden="true">{chapter.numeral}</span>
            <span class="flex-1 min-w-0">
              <span class="row-title">{chapter.title}</span>
              <span
                :if={Book.chapter_note(chapter)}
                class="block italic text-base text-ink-muted leading-snug"
              >
                {Book.chapter_note(chapter)}
              </span>
              <span class="row-fact">{Book.count_label(length(chapter.prayer_ids))}</span>
            </span>
            <span class="hero-chevron-right size-5 row-chevron" aria-hidden="true" />
          </.link>
        </li>
      </ol>
    </section>
    """
  end

  @doc "A shelf's label, with the way to the chapter it is drawn from."
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :to, :string, required: true

  def shelf_heading(assigns) do
    ~H"""
    <div class="flex items-center gap-4 mb-1">
      <h2 id={@id} class="section-label flex-1 min-w-0 !mb-0">{@title}</h2>
      <.link navigate={@to} class="btn-text shrink-0" aria-describedby={@id}>
        See all <span class="hero-chevron-right size-3.5" aria-hidden="true" />
      </.link>
    </div>
    """
  end

  @doc "A painting from the Prayers page's list, framed about its subject."
  attr :painting, :any, required: true, doc: "`{name, focal y}`"
  attr :sizes, :string, required: true
  attr :class, :any, default: nil

  def painting(assigns) do
    {name, focal_y} = assigns.painting

    assigns =
      assign(assigns, name: name, position: "object-position: 50% #{round(focal_y * 100)}%")

    ~H"""
    <MysteryPainting.picture name={@name} sizes={@sizes} alt="" class={@class} style={@position} />
    """
  end
end
