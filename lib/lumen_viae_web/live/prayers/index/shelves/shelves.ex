defmodule LumenViaeWeb.Live.Prayers.Index.Shelves do
  @moduledoc """
  The Prayers page's shelves, as the app's Prayers tab draws them
  (`PrayersComponents.swift`): the shortcuts to the orders of prayer, a
  painting and a name on the card ground; Now, the hour's order as one
  wide card with PRAY on an outlined disc; Everyday Prayers as rows with
  a painting, then Prayers to Mary and All
  Topics as shelves of square painted cards, a name and a line under each
  (`PrayersSquareCard`). All Topics is a shelf for each of the book's five
  parts. On a phone a shelf scrolls sideways inside itself, as in the app;
  from 640px its cards wrap.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Prayers.{Book, Orders}

  import LumenViaeWeb.Live.Prayers.Painting

  attr :orders, :list, required: true
  attr :today, Date, required: true

  @doc """
  The shortcuts at the head of the page (PrayersShortcutTile): the day's
  three orders, then Before Mass and Before Confession, each its painting
  at the leading edge and its name for the day.
  """
  def shortcuts(assigns) do
    ~H"""
    <section aria-labelledby="shortcuts-heading" class="min-w-0">
      <h2 id="shortcuts-heading" class="sr-only">Orders of prayer</h2>
      <ul class="prayers-shortcuts">
        <li :for={order <- @orders}>
          <.link
            navigate={Orders.order_path(order.id)}
            class="prayers-shortcut"
            data-role="shortcut"
          >
            <span class="prayers-shortcut__painting" aria-hidden="true">
              <.painting painting={Orders.painting(order, @today)} sizes="56px" />
            </span>
            <span class="prayers-shortcut__title">{Orders.title(order, @today)}</span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :order, :map, required: true
  attr :today, Date, required: true
  attr :hour, :integer, required: true

  @doc """
  Now (PrayersNowCard): the order for the hour it is as one wide card, its
  painting, NOW and the hour's name, its title and its line; the card
  opens the order's page, and PRAY, over its foot, prays it. The website
  keeps nothing of what was prayed, so it never says PRAYED.
  """
  def now_card(assigns) do
    assigns =
      assign(assigns,
        title: Orders.title(assigns.order, assigns.today),
        hour_name: Orders.hour_name(assigns.order.id, assigns.hour)
      )

    ~H"""
    <section aria-labelledby="now-heading" class="min-w-0">
      <h2 id="now-heading" class="section-label">Now</h2>
      <div class="prayers-now" data-role="now-card" data-order={@order.id}>
        <.link
          navigate={Orders.order_path(@order.id)}
          class="prayers-now__face"
          aria-label={"#{@title}, the prayer for this hour. #{Orders.day_summary(@order, @today)}"}
        >
          <span class="prayers-now__painting" aria-hidden="true">
            <.painting painting={Orders.hour_painting(@order, @today)} sizes="136px" />
          </span>
          <span class="prayers-now__words">
            <span class="prayers-now__kicker">Now · {@hour_name}</span>
            <span class="prayers-now__title">{@title}</span>
            <span class="prayers-now__summary">{Orders.day_summary(@order, @today)}</span>
          </span>
        </.link>
        <.link
          navigate={Orders.pray_path(@order.id)}
          class="prayers-now__pray"
          aria-label={"Pray #{@title}"}
          data-role="now-pray"
        >
          <span class="prayers-now__disc" aria-hidden="true">
            <span class="hero-play-solid size-3.5" />
          </span>
          Pray
        </.link>
      </div>
    </section>
    """
  end

  attr :rows, :list, required: true, doc: "`%{prayer:, painting:}`"

  def everyday(assigns) do
    ~H"""
    <section aria-labelledby="everyday-heading" class="min-w-0">
      <.shelf_heading
        id="everyday-heading"
        title="Everyday Prayers"
        to={Book.chapter_path(Book.first_chapter_id())}
      />
      <ul class="row-list">
        <li :for={%{prayer: prayer, painting: painting} <- @rows}>
          <.link navigate={Book.prayer_path(prayer.id)} class="row-link" data-role="everyday-row">
            <span class="arch-thumb w-14 h-14" aria-hidden="true">
              <.painting painting={painting} sizes="56px" class="w-full h-full object-cover" />
            </span>
            <span class="flex-1 min-w-0">
              <span class="row-title">{Book.list_name(prayer)}</span>
              <span
                :if={prayer.english_name}
                class="block italic text-base text-ink-muted leading-snug"
              >
                {prayer.english_name}
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
    <section aria-labelledby="mary-heading" class="min-w-0">
      <.shelf_heading
        id="mary-heading"
        title="Prayers to Mary"
        to={Book.chapter_path(Book.our_lady_chapter_id())}
      />
      <ul class="book-shelf mt-3">
        <li :for={card <- @cards}>
          <.square_card
            to={Book.prayer_path(card.prayer.id)}
            title={Book.list_name(card.prayer)}
            note={card.note}
            painting={card.painting}
            role={if card.seasonal?, do: "seasonal-card", else: "marian-card"}
          />
        </li>
      </ul>
    </section>
    """
  end

  attr :parts, :list, required: true

  def all_topics(assigns) do
    ~H"""
    <section aria-labelledby="topics-heading" class="min-w-0">
      <h2 id="topics-heading" class="section-label">All Topics</h2>
      <div class="space-y-7 mt-4">
        <section
          :for={{part, i} <- Enum.with_index(@parts)}
          :if={part.chapters != []}
          aria-labelledby={"part-#{i}"}
          data-role="book-part"
        >
          <h3 id={"part-#{i}"} class="kicker mb-3">{part.title}</h3>
          <ul class="book-shelf">
            <li :for={chapter <- part.chapters}>
              <.square_card
                to={Book.chapter_path(chapter.id)}
                title={chapter.title}
                note={Book.count_label(length(chapter.prayer_ids))}
                painting={Book.topic_painting(chapter.id)}
                role="topic-tile"
              />
            </li>
          </ul>
        </section>
      </div>
    </section>
    """
  end

  @doc "A square painting with a name and a line under it, the whole card a link."
  attr :to, :string, required: true
  attr :title, :string, required: true
  attr :note, :string, default: nil
  attr :painting, :any, required: true
  attr :role, :string, required: true

  def square_card(assigns) do
    ~H"""
    <.link navigate={@to} class="book-card" data-role={@role}>
      <span class="book-card__painting" aria-hidden="true">
        <.painting painting={@painting} sizes="(min-width: 640px) 160px, 138px" />
      </span>
      <span class="book-card__title">{@title}</span>
      <span :if={@note} class="book-card__note">{@note}</span>
    </.link>
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
end
