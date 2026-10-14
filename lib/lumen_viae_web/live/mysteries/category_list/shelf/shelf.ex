defmodule LumenViaeWeb.Live.Mysteries.CategoryList.Shelf do
  @moduledoc """
  The category's meditation sets: the filters (each kind of meditation the
  shelf carries, and narrated only) in one row, "Let one be chosen for
  me", and one card per set with its painting or author's portrait,
  byline, kinds, narration and the start of its description, each card a
  Pray link carrying the visitor's choices.
  """
  use LumenViaeWeb, :html

  alias LumenViae.Rosary.Labels
  alias LumenViaeWeb.Components.SetPortrait
  alias LumenViaeWeb.Live.Mysteries.CategoryList.{Filtering, PrayLinks}

  attr :title, :string, required: true
  attr :sets, :list, required: true, doc: "every visible set of the category"
  attr :shown_sets, :list, required: true, doc: "the sets passing the filters"
  attr :filters, :map, required: true
  attr :kinds_offered, :list, required: true
  attr :choices, :map, required: true

  def shelf(assigns) do
    assigns = assign(assigns, :any_narrated?, Enum.any?(assigns.sets, &Filtering.narrated?/1))

    ~H"""
    <section aria-labelledby="sets-heading">
      <h2 id="sets-heading" class="section-label">Meditations</h2>

      <%= if @sets == [] do %>
        <div class="category-card px-6 py-10 text-center">
          <p class="font-garamond text-xl text-ink-light italic mb-2">
            No meditation sets are available yet for {@title}.
          </p>
          <p class="font-garamond text-ink-muted text-base">
            New sets are added regularly. In the meantime, pray the Scriptural
            Rosary or the Rosary Said Aloud above.
          </p>
        </div>
      <% else %>
        <div :if={@kinds_offered != [] or @any_narrated?} role="group" aria-labelledby="filters-label">
          <p id="filters-label" class="sr-only">Filter by kind</p>
          <%!-- One row that scrolls sideways on a phone, not a wrapping block. --%>
          <div class="tab-scroller flex gap-2 overflow-x-auto -mx-4 px-4 pb-1 sm:mx-0 sm:px-0 sm:flex-wrap sm:overflow-visible">
            <button
              :for={kind <- @kinds_offered}
              type="button"
              phx-click="toggle_kind"
              phx-value-kind={kind}
              aria-pressed={to_string(kind in @filters.kinds)}
              class="category-chip shrink-0 whitespace-nowrap"
            >
              {Labels.display_name(kind)}
            </button>
            <button
              :if={@any_narrated?}
              type="button"
              phx-click="toggle_narrated"
              aria-pressed={to_string(@filters.narrated)}
              class="category-chip shrink-0 whitespace-nowrap"
            >
              Narrated only
            </button>
          </div>
          <p
            :if={Filtering.active?(@filters)}
            class="font-garamond text-base text-ink-muted mt-2"
            aria-live="polite"
          >
            Showing {length(@shown_sets)} of {length(@sets)} sets.
            <button type="button" phx-click="clear_filters" class="btn-text">
              Clear filters
            </button>
          </p>
        </div>

        <p class="mt-1 mb-3">
          <button type="button" phx-click="providence" class="btn-text">
            Let one be chosen for me
          </button>
        </p>

        <%= if @shown_sets == [] do %>
          <div class="category-card px-6 py-8 text-center">
            <p class="font-garamond text-lg text-ink-light italic mb-3">
              No meditations match all of those kinds.
            </p>
            <button type="button" phx-click="clear_filters" class="category-quiet-btn">
              Clear filters
            </button>
          </div>
        <% else %>
          <ul class="grid gap-3 md:grid-cols-2 lg:grid-cols-1" id="meditation-sets">
            <li :for={set <- @shown_sets} id={"set-#{set.id}"} class="min-w-0">
              <.set_card set={set} choices={@choices} />
            </li>
          </ul>
        <% end %>
      <% end %>
    </section>
    """
  end

  attr :set, :map, required: true
  attr :choices, :map, required: true

  defp set_card(assigns) do
    set = assigns.set

    assigns =
      assigns
      |> assign(:byline, byline(set))
      |> assign(:meta, meta(set))

    ~H"""
    <article class="category-card relative flex gap-4 p-4 h-full">
      <SetPortrait.set_portrait
        set={@set}
        sizes="(min-width: 640px) 80px, 64px"
        class="w-16 h-20 sm:w-20 sm:h-24 self-start"
      />

      <div class="min-w-0 flex-1 flex flex-col">
        <h3 class="font-display text-[1.375rem] font-semibold text-ink-light leading-tight break-words">
          <.link navigate={PrayLinks.set_path(@set.id, @choices)} class="category-stretched-link">
            {@set.name}
          </.link>
        </h3>
        <p :if={@byline} class="font-garamond italic text-base text-ink-muted leading-snug">
          {@byline}
        </p>
        <p :if={@meta} class="font-garamond text-sm text-sky mt-1 break-words">{@meta}</p>
        <p
          :if={@set.description}
          class="font-garamond text-base text-ink-muted leading-normal mt-1.5 line-clamp-2"
        >
          {@set.description}
        </p>
      </div>

      <span class="hero-chevron-right size-5 row-chevron self-center" aria-hidden="true" />
    </article>
    """
  end

  # The set's kinds and whether it is narrated, in one line.
  defp meta(set) do
    kinds = Enum.map(set.labels || [], &Labels.display_name/1)
    words = if Filtering.narrated?(set), do: kinds ++ ["Narrated"], else: kinds

    case words do
      [] -> nil
      words -> Enum.join(words, " · ")
    end
  end

  # The set's own byline, else its linked author's name, else the author
  # its meditations agree on.
  defp byline(set) do
    case author_name(set) do
      name when name == set.name -> nil
      name -> name
    end
  end

  defp author_name(set), do: LumenViaeWeb.PageMeta.set_author(set)
end
