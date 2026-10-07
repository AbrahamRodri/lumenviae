defmodule LumenViaeWeb.Live.Mysteries.CategoryList.WaysToPray do
  @moduledoc """
  The Rosary's two forms that need no meditation set, for this category:
  the Scriptural Rosary (a verse for every Hail Mary) and the Rosary Said
  Aloud (every prayer, no readings). Each row says how it will be prayed
  with the visitor's choices.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Mysteries.CategoryList.PrayLinks

  attr :category, :string, required: true
  attr :choices, :map, required: true

  def ways_to_pray(assigns) do
    assigns =
      assign(assigns, :ways, [
        %{
          form: :scriptural,
          title: "The Scriptural Rosary",
          detail: "A Bible verse for every Hail Mary"
        },
        %{form: :holy, title: "The Rosary Said Aloud", detail: "Every prayer, no readings"}
      ])

    ~H"""
    <section aria-labelledby="ways-heading">
      <h2 id="ways-heading" class="category-section-label">Ways to Pray</h2>
      <ul class="grid gap-3 sm:grid-cols-2">
        <li :for={way <- @ways} class="category-card relative flex min-w-0 items-start gap-4 p-4 sm:p-5">
          <span class="category-glyph" aria-hidden="true">
            <svg
              :if={way.form == :scriptural}
              viewBox="0 0 24 24"
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              stroke-width="1.4"
            >
              <path d="M4 5.5C4 4.7 4.7 4 5.5 4H11v16H5.5C4.7 20 4 19.3 4 18.5v-13zM20 5.5C20 4.7 19.3 4 18.5 4H13v16h5.5c.8 0 1.5-.7 1.5-1.5v-13z" />
              <path d="M7 8h2M15 8h2" />
            </svg>
            <svg
              :if={way.form == :holy}
              viewBox="0 0 24 24"
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              stroke-width="1.4"
            >
              <path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5H4z" />
              <path d="M15.5 9a4 4 0 010 6M17.8 6.5a7.5 7.5 0 010 11" />
            </svg>
          </span>
          <div class="min-w-0">
            <h3 class="font-cinzel text-base text-navy leading-snug">
              <.link
                navigate={PrayLinks.way_path(@category, way.form, @choices)}
                class="category-stretched-link"
                data-role={"way-#{way.form}"}
              >
                {way.title}
              </.link>
            </h3>
            <p class="font-garamond text-base text-brown">{way.detail}</p>
            <p class="font-cinzel text-xs tracking-[0.15em] uppercase text-gold-dark mt-1.5">
              {PrayLinks.summary(way.form, @choices)}
            </p>
          </div>
        </li>
      </ul>
    </section>
    """
  end
end
