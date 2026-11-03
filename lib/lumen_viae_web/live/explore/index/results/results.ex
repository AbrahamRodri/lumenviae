defmodule LumenViaeWeb.Live.Explore.Index.Results do
  @moduledoc """
  What the one search found, drawn as the iOS app's `AppSearchResultsView`
  draws it: the kinds found as chips under the field, each with its count,
  each a jump to its section (they never filter); the best match as a
  painted card with its own act (Pray for an order of prayer, Listen for a
  chant); then a section per kind in Explore's order, at most twelve rows
  each before "And 3 more". Nothing found says so, and what to try.

  The finding and the order are `LumenViaeWeb.Live.Explore.Search`'s; this
  only draws.
  """
  use LumenViaeWeb, :html

  alias LumenViae.Rosary.Categories
  alias LumenViaeWeb.Components.MysteryPainting
  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Explore.Search
  alias LumenViaeWeb.Live.Prayers.{Book, Orders}

  import LumenViaeWeb.Live.Chants.Parts, only: [painted_row: 1]
  import LumenViaeWeb.Live.Prayers.Painting

  # How many of a kind are listed before the section says how many more
  # (AppSearchResultsView.rowLimit).
  @row_limit 12

  attr :results, Search, required: true

  @doc "The kinds found, each a link to its section, with its count (AppSearchChips)."
  def chips(assigns) do
    ~H"""
    <nav aria-label="Found" class="explore-chips" data-role="chips">
      <a
        :for={kind <- Search.found_kinds(@results)}
        href={Search.chip_target(@results, kind)}
        class="explore-chip"
        data-role="chip"
        aria-label={"#{Search.title(kind)}, #{Search.count(@results, kind)}"}
      >
        <span class="explore-chip__word">{Search.chip_title(kind)}</span>
        <span class="explore-chip__count">{Search.count(@results, kind)}</span>
      </a>
    </nav>
    """
  end

  attr :results, Search, required: true
  attr :book, :any, required: true

  @doc "The best card, then a section per kind; or Nothing found."
  def results(assigns) do
    assigns = assign(assigns, :row_limit, @row_limit)

    ~H"""
    <div id="explore-results" data-role="results">
      <div :if={Search.empty?(@results)} class="explore-nothing" data-role="no-match">
        <p class="explore-nothing__title">Nothing found</p>
        <p class="explore-nothing__line">Try a mystery, a prayer, a chant or a saint's name.</p>
      </div>

      <div :if={!Search.empty?(@results)} class="explore-results">
        <.best_card :if={@results.best} hit={@results.best} book={@book} date={@results.date} />

        <section
          :for={section <- @results.sections}
          id={"explore-#{section.kind}"}
          class="explore-section"
          aria-labelledby={"explore-#{section.kind}-heading"}
          data-role="section"
          data-kind={section.kind}
        >
          <h2 id={"explore-#{section.kind}-heading"} class="section-label">
            {Search.title(section.kind)}
          </h2>
          <ul class="row-list explore-rows">
            <li :for={hit <- Enum.take(section.hits, @row_limit)}>
              <.row hit={hit} book={@book} date={@results.date} />
            </li>
          </ul>
          <p :if={length(section.hits) > @row_limit} class="explore-more" data-role="more">
            And {length(section.hits) - @row_limit} more. Add a word to narrow the search.
          </p>
        </section>
      </div>
    </div>
    """
  end

  @doc """
  What VoiceOver hears in the app once the reader pauses: the kinds found
  and how many, or Nothing found.
  """
  def announcement(%Search{} = results) do
    if Search.empty?(results) do
      "Nothing found"
    else
      results
      |> Search.found_kinds()
      |> Enum.map_join("; ", &"#{Search.title(&1)}, #{Search.count(results, &1)}")
    end
  end

  ## The best match

  attr :hit, :any, required: true
  attr :book, :any, required: true
  attr :date, Date, required: true

  # The one card above the sections: the painting at its leading edge, what
  # kind of thing it is, its name, a line, and its act. The card itself
  # opens the thing's page; the act stands beside, a control of its own.
  defp best_card(assigns) do
    hit = assigns.hit

    assigns =
      assign(assigns,
        title: title(hit, assigns.date),
        kicker: kicker(hit, assigns.book),
        line: line(hit, assigns.date),
        path: path(hit),
        chant_id: chant_id(hit)
      )

    ~H"""
    <article
      id="explore-best"
      class="explore-best"
      data-role="best"
      data-kind={Search.kind(@hit)}
      data-chant-row={@chant_id}
    >
      <.link
        navigate={@path}
        class="explore-best__door"
        aria-label={
          Enum.join(Enum.reject(["Best match: #{@title}", @kicker, @line], &is_nil/1), ", ")
        }
      >
        <span class="explore-best__picture" aria-hidden="true">
          <.best_picture hit={@hit} book={@book} date={@date} />
        </span>
        <span class="explore-best__words">
          <span class="explore-best__kicker">{@kicker}</span>
          <span class="explore-best__title">{@title}</span>
          <span :if={@line} class="explore-best__line">{@line}</span>
          <span :if={act?(@hit)} class="explore-best__room" aria-hidden="true"></span>
        </span>
      </.link>
      <.act hit={@hit} title={@title} />
    </article>
    """
  end

  attr :hit, :any, required: true
  attr :title, :string, required: true

  defp act(%{hit: {:order, order}} = assigns) do
    assigns = assign(assigns, :order, order)

    ~H"""
    <.link
      navigate={Orders.pray_path(@order.id)}
      class="explore-best__act explore-best__pray"
      aria-label={"Pray #{@title}"}
      data-role="best-pray"
    >
      Pray
    </.link>
    """
  end

  defp act(%{hit: {:chant, chant}} = assigns) do
    assigns =
      assign(assigns,
        chant: chant,
        label: "#{chant.latin_title}, #{chant.english_title}"
      )

    ~H"""
    <button
      type="button"
      class="explore-best__act explore-best__listen"
      data-play={@chant.id}
      data-src={@chant.audio.url}
      data-label={@label}
      aria-label={"Play #{@label}"}
      aria-pressed="false"
      data-role="best-listen"
    >
      <span class="chant-disc explore-best__disc" aria-hidden="true">
        <span class="hero-play-solid size-3 chant-disc__play" />
        <span class="hero-pause-solid size-3 chant-disc__pause" />
      </span>
      <span class="explore-best__listen-word" aria-hidden="true">Listen</span>
      <span class="explore-best__pause-word" aria-hidden="true">Pause</span>
    </button>
    """
  end

  defp act(assigns), do: ~H""

  # A prayer has no pray-along of its own on the website, so its card is
  # the door alone; the app's PRAY there opens the prayer prayed along.
  defp act?({type, _}), do: type in [:order, :chant]

  defp chant_id({:chant, chant}), do: chant.id
  defp chant_id(_hit), do: nil

  attr :hit, :any, required: true
  attr :book, :any, required: true
  attr :date, Date, required: true

  defp best_picture(%{hit: {type, _}} = assigns) when type in [:page, :set] do
    assigns = assign(assigns, :icon, glyph(assigns.hit))

    ~H"""
    <span class="explore-best__glyph"><span class={[@icon, "size-7"]} /></span>
    """
  end

  defp best_picture(assigns) do
    ~H"""
    <.picture hit={@hit} book={@book} date={@date} sizes="(min-width: 640px) 160px, 118px" />
    """
  end

  ## Rows

  attr :hit, :any, required: true
  attr :book, :any, required: true
  attr :date, Date, required: true

  # A chant is the Chant Library's own row, its disc playing it where it
  # stands.
  defp row(%{hit: {:chant, chant}} = assigns) do
    assigns = assign(assigns, :chant, chant)

    ~H"""
    <.painted_row chant={@chant} />
    """
  end

  # A door of the site or a meditation set: an icon in the arched frame.
  defp row(%{hit: {type, _}} = assigns) when type in [:page, :set] do
    hit = assigns.hit

    assigns =
      assign(assigns,
        icon: glyph(hit),
        title: title(hit, assigns.date),
        note: note(hit, assigns.book),
        path: path(hit)
      )

    ~H"""
    <.link navigate={@path} class="row-link explore-row" data-role="result-row">
      <span class="glyph-badge explore-row__glyph" aria-hidden="true">
        <span class={[@icon, "size-5"]} />
      </span>
      <span class="flex-1 min-w-0">
        <span class="explore-row__title">{@title}</span>
        <span :if={@note} class="explore-row__note">{@note}</span>
      </span>
      <span class="hero-chevron-right size-5 row-chevron" aria-hidden="true" />
    </.link>
    """
  end

  # Anything with a picture: the painting, its name, a line, a caret.
  defp row(assigns) do
    hit = assigns.hit

    assigns =
      assign(assigns,
        title: title(hit, assigns.date),
        note: note(hit, assigns.book),
        path: path(hit)
      )

    ~H"""
    <.link navigate={@path} class="row-link explore-row" data-role="result-row">
      <span class="explore-row__picture" aria-hidden="true">
        <.picture hit={@hit} book={@book} date={@date} sizes="44px" />
      </span>
      <span class="flex-1 min-w-0">
        <span class="explore-row__title">{@title}</span>
        <span :if={@note} class="explore-row__note">{@note}</span>
      </span>
      <span class="hero-chevron-right size-5 row-chevron" aria-hidden="true" />
    </.link>
    """
  end

  attr :hit, :any, required: true
  attr :book, :any, required: true
  attr :date, Date, required: true
  attr :sizes, :string, required: true

  # The painting a hit hangs: a mystery's own, a devotion's card, a topic's,
  # an order's, a prayer's scene, a chant's.
  defp picture(%{hit: {:mysteries, slug}} = assigns) do
    assigns = assign(assigns, :slug, slug)

    ~H"""
    <MysteryPainting.picture category={@slug} sizes={@sizes} alt="" style={card_position(@slug)} />
    """
  end

  defp picture(%{hit: {:mystery, mystery}} = assigns) do
    key = "#{mystery.category}_#{mystery.order}"

    assigns =
      assign(assigns,
        key: if(MysteryPainting.for_mystery(key), do: key),
        slug: mystery.category
      )

    ~H"""
    <MysteryPainting.picture :if={@key} key={@key} sizes={@sizes} alt="" />
    <MysteryPainting.picture
      :if={!@key}
      category={@slug}
      sizes={@sizes}
      alt=""
      style={card_position(@slug)}
    />
    """
  end

  defp picture(assigns) do
    assigns = assign(assigns, :painting, painting(assigns.hit, assigns.book, assigns.date))

    ~H"""
    <.painting painting={@painting} sizes={@sizes} />
    """
  end

  defp painting({:topic, chapter}, _book, _date), do: Book.topic_painting(chapter.id)
  defp painting({:order, order}, _book, date), do: Orders.page_painting(order, date)
  defp painting({:prayer, prayer}, book, _date), do: Book.prayer_painting(book, prayer.id)
  defp painting({:chant, chant}, _book, _date), do: Library.painting(chant)

  defp card_position(slug) do
    {x, y} = Categories.card_focal_point(slug)
    "object-position: #{round(x * 100)}% #{round(y * 100)}%"
  end

  ## Words

  defp title({:mysteries, slug}, _date), do: Categories.devotion_title(slug)
  defp title({:mystery, mystery}, _date), do: mystery.name
  defp title({:page, page}, _date), do: page.title
  defp title({:topic, chapter}, _date), do: chapter.topic
  defp title({:order, order}, date), do: Orders.title(order, date)
  defp title({:prayer, prayer}, _date), do: Book.list_name(prayer)
  defp title({:chant, chant}, _date), do: chant.latin_title
  defp title({:set, set}, _date), do: set.name

  # A row's line (AppSearchResultsView.row).
  defp note({:mysteries, slug}, _book), do: Categories.subtitle(slug)
  defp note({:mystery, mystery}, _book), do: Categories.devotion_title(mystery.category)
  defp note({:page, _page}, _book), do: nil
  defp note({:topic, chapter}, _book), do: Book.count_label(length(chapter.prayer_ids))
  defp note({:order, order}, _book), do: order.occasion
  defp note({:prayer, prayer}, book), do: prayer_note(prayer, book)
  defp note({:set, set}, _book), do: Search.set_note(set)

  # A prayer's line: the name it also goes by, else the topic it stands in.
  defp prayer_note(prayer, book) do
    Book.second_title(prayer) ||
      case Book.home_chapter(book, prayer.id) do
        nil -> nil
        chapter -> chapter.title
      end
  end

  # What kind of thing the best match is (AppSearchBestCard.kicker).
  defp kicker({:prayer, prayer}, book) do
    case Book.home_chapter(book, prayer.id) do
      nil -> "Prayer"
      chapter -> chapter.title
    end
  end

  defp kicker({:topic, _}, _book), do: "Topic"
  defp kicker({:order, _}, _book), do: "Prayers said together"
  defp kicker({:chant, chant}, _book), do: Library.form_name(chant)
  defp kicker({:mysteries, _}, _book), do: "Rosary Mysteries"
  defp kicker({:mystery, mystery}, _book), do: Categories.devotion_title(mystery.category)
  defp kicker({:page, _}, _book), do: "Page"
  defp kicker({:set, _}, _book), do: "Meditation"

  # The best card's line (AppSearchBestCard.line): the chant's setting
  # where neither title says it, so the two Salve Reginas are told apart.
  defp line({:prayer, prayer}, _date), do: Book.second_title(prayer)
  defp line({:topic, chapter}, _date), do: Book.count_label(length(chapter.prayer_ids))
  defp line({:order, order}, _date), do: order.occasion

  defp line({:chant, chant}, _date) do
    [chant.english_title, Library.setting_mid_line(chant), Library.duration_label(chant.duration)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp line({:mysteries, slug}, _date), do: Categories.subtitle(slug)
  defp line({:mystery, _}, _date), do: nil
  defp line({:page, _}, _date), do: nil
  defp line({:set, set}, _date), do: Search.set_note(set)

  defp glyph({:page, page}), do: page.icon
  defp glyph({:set, _set}), do: "hero-rectangle-stack"

  # Where a hit opens. A mystery opens its devotion's page, as the app's
  # does; a set its prayer page, as the website has no page of a set alone.
  defp path({:mysteries, slug}), do: "/mysteries/#{slug}"
  defp path({:mystery, mystery}), do: "/mysteries/#{mystery.category}"
  defp path({:page, page}), do: page.path
  defp path({:topic, chapter}), do: Book.chapter_path(chapter.id)
  defp path({:order, order}), do: Orders.order_path(order.id)
  defp path({:prayer, prayer}), do: Book.prayer_path(prayer.id)
  defp path({:chant, chant}), do: Library.chant_path(chant.id)
  defp path({:set, set}), do: "/meditation-sets/#{set.id}/pray"
end
