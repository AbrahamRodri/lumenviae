defmodule LumenViaeWeb.Live.Mysteries.CategoryList.Shelf do
  @moduledoc """
  The category's meditation sets: the filters (each kind of meditation the
  shelf carries, and narrated only), "Let one be chosen for me", and one
  card per set with its painting or author's portrait, byline, number of
  meditations, narration and kinds, each card a Pray link carrying the
  visitor's choices.
  """
  use LumenViaeWeb, :html

  alias LumenViae.Rosary
  alias LumenViae.Rosary.{Artwork, Labels}
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
      <h2 id="sets-heading" class="category-section-label">Meditations</h2>

      <%= if @sets == [] do %>
        <div class="category-card px-6 py-10 text-center">
          <p class="font-garamond text-xl text-navy italic mb-2">
            No meditation sets are available yet for {@title}.
          </p>
          <p class="font-garamond text-brown-light text-base">
            New sets are added regularly. In the meantime, pray the Scriptural
            Rosary or the Rosary Said Aloud above.
          </p>
        </div>
      <% else %>
        <p class="font-garamond text-base text-brown mb-4 max-w-[60ch]">
          Each set contemplates the same mysteries through a different light: a
          meditation is read before each decade.
        </p>

        <div class="category-card px-5 py-4 mb-6 flex flex-col sm:flex-row sm:items-center gap-3 sm:justify-between">
          <div>
            <p class="font-cinzel text-[0.7rem] tracking-[0.2em] uppercase text-gold-dark">
              Divine Providence
            </p>
            <p class="font-garamond text-base text-brown">
              Not sure which to pray? Let a set be chosen for you.
            </p>
          </div>
          <button type="button" phx-click="providence" class="category-quiet-btn shrink-0">
            Let one be chosen for me
          </button>
        </div>

        <div
          :if={@kinds_offered != [] or @any_narrated?}
          role="group"
          aria-labelledby="filters-label"
          class="mb-5"
        >
          <p
            id="filters-label"
            class="font-cinzel text-[0.7rem] tracking-[0.2em] uppercase text-navy mb-2"
          >
            Filter by kind
          </p>
          <div class="flex flex-wrap gap-2">
            <button
              :for={kind <- @kinds_offered}
              type="button"
              phx-click="toggle_kind"
              phx-value-kind={kind}
              aria-pressed={to_string(kind in @filters.kinds)}
              class="category-chip"
            >
              {Labels.display_name(kind)}
            </button>
            <button
              :if={@any_narrated?}
              type="button"
              phx-click="toggle_narrated"
              aria-pressed={to_string(@filters.narrated)}
              class="category-chip"
            >
              Narrated only
            </button>
          </div>
          <p
            :if={Filtering.active?(@filters)}
            class="font-garamond text-sm text-brown-light mt-2"
            aria-live="polite"
          >
            Showing {length(@shown_sets)} of {length(@sets)} sets.
            <button type="button" phx-click="clear_filters" class="category-text-btn">
              Clear filters
            </button>
          </p>
        </div>

        <%= if @shown_sets == [] do %>
          <div class="category-card px-6 py-8 text-center">
            <p class="font-garamond text-lg text-navy italic mb-3">
              No meditations match all of those kinds.
            </p>
            <button type="button" phx-click="clear_filters" class="category-quiet-btn">
              Clear filters
            </button>
          </div>
        <% else %>
          <ul class="grid gap-4 md:grid-cols-2 lg:grid-cols-1" id="meditation-sets">
            <li :for={set <- @shown_sets} id={"set-#{set.id}"}>
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
    artwork = Rosary.artwork_record(set)

    assigns =
      assigns
      |> assign(:artwork, artwork)
      |> assign(:byline, byline(set))
      |> assign(:count, length(set.meditations))
      |> assign(:narrated?, Filtering.narrated?(set))
      |> assign(:portrait_alt, artwork && artwork.image_alt)

    ~H"""
    <article class="category-card relative flex gap-4 p-4 sm:p-5 h-full">
      <div class="w-20 sm:w-24 shrink-0">
        <%= if @artwork do %>
          <img
            src={Rosary.artwork_url(@artwork)}
            alt={@portrait_alt}
            loading="lazy"
            class="w-full aspect-[4/5] object-cover rounded-t-full border border-gold/40"
            style={"object-position: #{Artwork.object_position(@artwork.image_focal_x, @artwork.image_focal_y)}"}
          />
        <% else %>
          <div
            class="w-full aspect-[4/5] rounded-t-full border border-gold/40 bg-cream flex items-center justify-center text-gold"
            aria-hidden="true"
          >
            <svg viewBox="0 0 10 14" class="w-4 h-5 fill-current">
              <path d="M3.6 0 H6.4 V2.8 H10 V5.6 H6.4 V14 H3.6 V5.6 H0 V2.8 H3.6 Z" />
            </svg>
          </div>
        <% end %>
      </div>

      <div class="min-w-0 flex flex-col">
        <h3 class="font-cinzel text-lg text-navy leading-snug">
          <.link navigate={PrayLinks.set_path(@set.id, @choices)} class="category-stretched-link">
            {@set.name}
          </.link>
        </h3>
        <p :if={@byline} class="font-garamond italic text-base text-brown">{@byline}</p>

        <p class="font-cinzel text-[0.65rem] tracking-[0.15em] uppercase text-brown-light mt-1.5">
          {@count} {if @count == 1, do: "meditation", else: "meditations"}
          <span :if={@narrated?}>
            <span aria-hidden="true"> &middot; </span><span class="text-gold-dark">Narrated</span>
          </span>
        </p>
        <p
          :if={(@set.labels || []) != []}
          class="font-cinzel text-[0.6rem] tracking-[0.18em] uppercase text-gold-dark mt-1"
        >
          {Enum.map_join(@set.labels, " · ", &Labels.display_name/1)}
        </p>

        <p
          :if={@set.description}
          class="font-garamond text-base text-brown leading-relaxed mt-2 line-clamp-3"
        >
          {@set.description}
        </p>

        <span
          class="font-cinzel text-[0.7rem] tracking-[0.15em] uppercase text-gold-dark mt-auto pt-3"
          aria-hidden="true"
        >
          Pray <span class="category-arrow">&rarr;</span>
        </span>
      </div>
    </article>
    """
  end

  # The set's own byline, else its linked author's name, else the author
  # its meditations agree on.
  defp byline(set) do
    case author_name(set) do
      name when name == set.name -> nil
      name -> name
    end
  end

  defp author_name(set) do
    profile_name =
      case Map.get(set, :author_profile) do
        %{name: name} -> name
        _none -> nil
      end

    blank_to_nil(set.author) || blank_to_nil(profile_name) ||
      blank_to_nil(Map.get(set, :derived_author))
  end

  defp blank_to_nil(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp blank_to_nil(_value), do: nil
end
