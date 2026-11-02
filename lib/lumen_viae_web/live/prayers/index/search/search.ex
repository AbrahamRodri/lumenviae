defmodule LumenViaeWeb.Live.Prayers.Index.Search do
  @moduledoc """
  The Prayers page's search, as the app's: the field, and what it found.
  The form is a plain GET to `/prayers`, so it works before the page
  connects; once it has, every keystroke patches `?q=` in place. The
  results say how many prayers match, show up to two topics the words name
  as cards and up to three orders of prayer as rows with their painting
  and when they are said (the app's search, "Prayers said together"), then
  the prayers, each with the chapter it belongs to.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Prayers.{Book, Orders}

  import LumenViaeWeb.Live.Prayers.Painting

  @hint ~s(Type a prayer's name or a word from it: "Memorare", "Joseph", "mercy".)
  @no_match ~s(No prayer by that name. Try a word from it — "mercy", "Joseph", "light".)

  attr :query, :string, required: true

  def search_form(assigns) do
    assigns = assign(assigns, :hint, @hint)

    ~H"""
    <form
      id="prayer-search"
      action="/prayers"
      method="get"
      role="search"
      phx-change="search"
      phx-submit="search"
      class="mt-6 md:mt-0 min-w-0"
    >
      <label for="prayer-search-field" class="kicker block mb-1.5">Search prayers</label>
      <div class="prayers-search">
        <span class="hero-magnifying-glass size-5 text-ink-muted shrink-0" aria-hidden="true" />
        <input
          id="prayer-search-field"
          type="search"
          name="q"
          value={@query}
          placeholder="Hail Mary, St Joseph…"
          autocomplete="off"
          spellcheck="false"
          phx-debounce="200"
          aria-describedby="prayer-search-hint"
          class="prayers-search__field"
        />
      </div>
      <p id="prayer-search-hint" class="italic text-base text-ink-muted mt-2 leading-snug">
        {@hint}
      </p>
    </form>
    """
  end

  attr :book, :any, required: true
  attr :query, :string, required: true
  attr :hits, :list, required: true
  attr :topics, :list, required: true
  attr :orders, :list, default: []
  attr :today, Date, required: true
  attr :seasonal_id, :string, default: nil

  def search_results(assigns) do
    assigns = assign(assigns, :no_match, @no_match)

    ~H"""
    <section
      id="prayer-results"
      class="max-w-3xl"
      aria-labelledby="results-heading"
      aria-live="polite"
    >
      <h2 id="results-heading" class="section-label">Results</h2>

      <p
        :if={@hits == [] and @topics == [] and @orders == []}
        class="italic text-lg text-ink-muted"
        data-role="no-match"
      >
        {@no_match}
      </p>

      <p :if={@hits != []} class="row-fact !mt-0 mb-3" data-role="match-count">
        {match_count(length(@hits))}
      </p>

      <ul :if={@topics != []} class="grid gap-3 sm:grid-cols-2 mb-4">
        <li :for={chapter <- @topics}>
          <.link
            navigate={Book.chapter_path(chapter.id)}
            class="hairline-card prayers-topic-card"
            data-role="topic-card"
          >
            <span class="kicker block">Topic</span>
            <span class="row-title">{chapter.topic}</span>
            <span class="row-fact">{Book.count_label(length(chapter.prayer_ids))}</span>
          </.link>
        </li>
      </ul>

      <ul :if={@orders != []} class="row-list mb-4" aria-label="Prayers said together">
        <li :for={order <- @orders}>
          <.link
            navigate={Orders.order_path(order.id)}
            class="row-link"
            data-role="order-result"
          >
            <span class="prayers-result-painting" aria-hidden="true">
              <.painting painting={Orders.page_painting(order, @today)} sizes="44px" />
            </span>
            <span class="flex-1 min-w-0">
              <span class="kicker block !mb-0">Prayers said together</span>
              <span class="row-title">{Orders.title(order, @today)}</span>
              <span class="block italic text-base text-ink-muted leading-snug">
                {order.occasion}
              </span>
            </span>
            <span class="hero-chevron-right size-5 row-chevron" aria-hidden="true" />
          </.link>
        </li>
      </ul>

      <ul :if={@hits != []} class="row-list">
        <li :for={prayer <- @hits}>
          <.link navigate={Book.prayer_path(prayer.id)} class="row-link" data-role="result-row">
            <span class="flex-1 min-w-0">
              <span class="row-title">{Book.list_name(prayer)}</span>
              <span
                :if={chapter_note(@book, prayer, @seasonal_id)}
                class="block italic text-base text-ink-muted leading-snug"
              >
                {chapter_note(@book, prayer, @seasonal_id)}
              </span>
            </span>
            <span class="hero-chevron-right size-5 row-chevron" aria-hidden="true" />
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  defp match_count(1), do: "1 prayer matches"
  defp match_count(n), do: "#{n} prayers match"

  # The topic a found prayer belongs to: "The Blessed Virgin · this season".
  defp chapter_note(book, prayer, seasonal_id) do
    case Book.home_chapter(book, prayer.id) do
      nil -> nil
      chapter when prayer.id == seasonal_id -> "#{chapter.title} · this season"
      chapter -> chapter.title
    end
  end
end
