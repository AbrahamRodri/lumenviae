defmodule LumenViaeWeb.Live.Mysteries.CategoryList.Shelf do
  @moduledoc """
  The category's meditation sets: the filters (each kind of meditation the
  shelf carries, and narrated only) in one row, "Let one be chosen for
  me", and one painted tile per set, as the app's shelf draws it: its
  painting or author's portrait, name, byline, kinds and narration, each
  tile a Pray link carrying the visitor's choices.
  """
  use LumenViaeWeb, :html

  alias LumenViae.Rosary
  alias LumenViae.Rosary.{Artwork, Labels}
  alias LumenViaeWeb.Components.ArtworkPicture
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
            Rosary or the Audio Rosary above.
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
          <ul class="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-3" id="meditation-sets">
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
      |> assign(:artwork, Rosary.artwork_record(set))
      |> assign(:byline, byline(set))
      |> assign(:meta, meta(set))

    ~H"""
    <article class="paint-tile aspect-[1/1.08] h-full">
      <ArtworkPicture.artwork_picture
        :if={@artwork}
        record={@artwork}
        alt={@artwork.image_alt}
        sizes="(min-width: 768px) 220px, 47vw"
        class="paint-tile__image"
        style={"object-position: #{Artwork.object_position(@artwork.image_focal_x, @artwork.image_focal_y)}"}
      />
      <span
        :if={!@artwork}
        class="absolute inset-x-0 top-6 flex justify-center text-gilt"
        aria-hidden="true"
      >
        <svg viewBox="0 0 10 14" class="w-5 h-7 fill-current">
          <path d="M3.6 0 H6.4 V2.8 H10 V5.6 H6.4 V14 H3.6 V5.6 H0 V2.8 H3.6 Z" />
        </svg>
      </span>

      <div class="paint-tile__words">
        <h3 class="paint-tile__title break-words">
          <.link navigate={PrayLinks.set_path(@set.id, @choices)} class="category-stretched-link">
            {@set.name}
          </.link>
        </h3>
        <p :if={@byline} class="paint-tile__line">{@byline}</p>
        <p :if={@meta} class="paint-tile__fact">{@meta}</p>
      </div>
    </article>
    """
  end

  # The set's kinds in one line, and "Text only" for a set with no
  # narration: narration is the rule, so the exception is named.
  defp meta(set) do
    kinds = Enum.map(set.labels || [], &Labels.display_name/1)
    words = if Filtering.narrated?(set), do: kinds, else: kinds ++ ["Text only"]

    case words do
      [] -> nil
      words -> Enum.join(words, " · ")
    end
  end

  # The set's own byline, else its linked author's name, else the author
  # its meditations agree on; left off when the set is already named for
  # its author ("Venerable Fulton J. Sheen" by "Archbishop Fulton J.
  # Sheen").
  defp byline(set) do
    case author_name(set) do
      nil -> nil
      name -> if named_for?(set.name, name), do: nil, else: name
    end
  end

  defp named_for?(set_name, author) do
    surname = author |> String.split() |> List.last()
    String.contains?(set_name, surname)
  end

  defp author_name(set), do: LumenViaeWeb.PageMeta.set_author(set)
end
