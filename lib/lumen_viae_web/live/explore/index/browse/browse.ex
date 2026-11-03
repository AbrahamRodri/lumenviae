defmodule LumenViaeWeb.Live.Explore.Index.Browse do
  @moduledoc """
  Explore at rest, as the iOS app's `ExploreView` lays out its directory
  before a word is typed: the five devotions, each with its painting in a
  small lancet arch and what it is about; Prayers, the Prayer Book's
  orders kept for an occasion as a shelf of paintings, with All prayers;
  Chant, the library's ways in as painted tiles, with Chant Library; Hours
  of Prayer; and Spiritual Reading, the books, each cover opening its
  book. Nothing on it turns with the hour or the day.

  What the website does not have is left out: the Mass (the Daily Missal),
  the Spiritual Reading shelf's other books, and the app's Learn More,
  whose guides are archived on iOS too. The app's shelves give way to what
  the reader prayed and sang lately; the website keeps nothing of that, so
  they hold their defaults.
  """
  use LumenViaeWeb, :html

  alias LumenViae.Rosary.Categories
  alias LumenViaeWeb.Components.MysteryPainting
  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Prayers.Orders

  import LumenViaeWeb.Live.Prayers.Painting

  # The occasion orders, most needed first (ExploreShelves.prayerDefaults).
  @occasion_ids ~w(before_mass before_confession after_mass after_confession visit table holy_souls trouble)

  @doc "The orders on the Prayers shelf, those the book carries, in their order."
  def occasion_orders(book) do
    for id <- @occasion_ids, order = Orders.order(book, id), do: order
  end

  attr :orders, :list, required: true
  attr :chant_count, :integer, required: true
  attr :date, Date, required: true

  def browse(assigns) do
    ~H"""
    <div class="explore-browse" data-role="browse">
      <section aria-labelledby="explore-browse-mysteries" class="explore-browse__mysteries">
        <.shelf_head id="explore-browse-mysteries" title="Rosary Mysteries" />
        <ul class="row-list">
          <li :for={slug <- Categories.slugs()}>
            <.link
              navigate={"/mysteries/#{slug}"}
              class="row-link explore-devotion"
              data-role="devotion"
            >
              <span class="mystery-thumb shrink-0" aria-hidden="true">
                <MysteryPainting.picture
                  category={slug}
                  sizes="44px"
                  alt=""
                  class="w-full h-full object-cover"
                  style={card_position(slug)}
                />
              </span>
              <span class="flex-1 min-w-0">
                <span class="row-title">{Categories.devotion_title(slug)}</span>
                <span class="explore-row__note">{Categories.subtitle(slug)}</span>
              </span>
              <span class="hero-chevron-right size-5 row-chevron" aria-hidden="true" />
            </.link>
          </li>
        </ul>
      </section>

      <section aria-labelledby="explore-browse-prayers" class="explore-browse__wide">
        <.shelf_head
          id="explore-browse-prayers"
          title="Prayers"
          link={{"All prayers", "/prayers"}}
        />
        <ul class="book-shelf">
          <li :for={order <- @orders}>
            <.link
              navigate={Orders.order_path(order.id)}
              class="book-card"
              data-role="occasion"
            >
              <span class="book-card__painting" aria-hidden="true">
                <.painting
                  painting={Orders.painting(order, @date)}
                  sizes="(min-width: 640px) 160px, 138px"
                />
              </span>
              <span class="book-card__title">{Orders.title(order, @date)}</span>
            </.link>
          </li>
        </ul>
      </section>

      <section aria-labelledby="explore-browse-chant">
        <.shelf_head
          id="explore-browse-chant"
          title="Chant"
          link={{"Chant Library", "/chant"}}
        />
        <ul class="explore-tiles">
          <li>
            <.tile
              title={"All #{@chant_count} Chants"}
              href="/chant#all-heading"
              painting={{"glorious_pentecost", 0.5, 0.3}}
            />
          </li>
          <li>
            <.tile
              title="Songs to Mary"
              href="/chant#mary-heading"
              painting={{"mary_sistine_madonna", 0.5, 0.25}}
            />
          </li>
          <li>
            <.tile
              title="Mass of the Angels"
              href={Library.section_path(Library.mass_of_the_angels_id())}
              painting={{"luminous_proclamation", 0.5, 0.3}}
            />
          </li>
          <li>
            <.tile
              title="Sets of Chants"
              href="/chant/sets"
              painting={{"feast_our_lady_of_the_rosary", 0.5, 0.3}}
            />
          </li>
        </ul>
      </section>

      <div class="explore-browse__pair">
        <section aria-labelledby="explore-browse-hours">
          <.shelf_head id="explore-browse-hours" title="Hours of Prayer" />
          <ul class="explore-tiles explore-tiles--one">
            <li>
              <.tile
                title="Hours of Prayer"
                note="Divine Office"
                href="/hours"
                painting={{"hour_morning", 0.5, 0.35}}
              />
            </li>
          </ul>
        </section>

        <section aria-labelledby="explore-browse-reading">
          <.shelf_head id="explore-browse-reading" title="Spiritual Reading" />
          <.link
            navigate="/true-devotion"
            class="explore-book"
            aria-label="True Devotion to Mary, St. Louis de Montfort"
            data-role="book"
          >
            <span class="td-cover explore-book__cover" aria-hidden="true">
              <span class="td-cover__frame"></span>
              <span class="td-cover__gilt"></span>
              <span class="td-cover__title">True Devotion to Mary</span>
              <span class="td-cover__lozenge"></span>
              <span class="td-cover__author">St. Louis de Montfort</span>
              <span class="td-cover__gilt"></span>
            </span>
          </.link>
        </section>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :link, :any, default: nil, doc: "`{words, path}`: the shelf's way to the whole of it"

  # The label running out on a fading rule, and the shelf's link at its end.
  defp shelf_head(assigns) do
    ~H"""
    <div class="explore-shelf-head">
      <h2 id={@id} class="section-label flex-1 min-w-0 !mb-0">{@title}</h2>
      <.link :if={@link} navigate={elem(@link, 1)} class="btn-text shrink-0">
        {elem(@link, 0)}<span class="hero-chevron-right size-3" aria-hidden="true" />
      </.link>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :note, :string, default: nil
  attr :href, :string, required: true
  attr :painting, :any, required: true

  # A painting run to a small card's edges, its name on a scrim along the
  # foot (ExploreView.paintedTile).
  defp tile(assigns) do
    ~H"""
    <.link navigate={@href} class="explore-tile" data-role="tile">
      <span class="explore-tile__painting" aria-hidden="true">
        <.painting painting={@painting} sizes="(min-width: 1024px) 280px, 46vw" />
      </span>
      <span class="explore-tile__words">
        <span class="explore-tile__title">{@title}</span>
        <span :if={@note} class="explore-tile__note">{@note}</span>
      </span>
    </.link>
    """
  end

  defp card_position(slug) do
    {x, y} = Categories.card_focal_point(slug)
    "object-position: #{round(x * 100)}% #{round(y * 100)}%"
  end
end
