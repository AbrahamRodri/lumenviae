defmodule LumenViaeWeb.Live.Mysteries.CategoryList.WaysToPray do
  @moduledoc """
  The Rosary's two forms that need no meditation set, for this category:
  the Scriptural Rosary (a verse for every Hail Mary) and the Audio
  Rosary (listen and pray along). Each row says how it will be prayed
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
        %{form: :holy, title: "The Audio Rosary", detail: "Listen and pray along"}
      ])

    ~H"""
    <section aria-labelledby="ways-heading">
      <h2 id="ways-heading" class="section-label">Ways to Pray</h2>
      <ul class="row-list">
        <li :for={way <- @ways}>
          <.link
            navigate={PrayLinks.way_path(@category, way.form, @choices)}
            class="row-link"
            data-role={"way-#{way.form}"}
          >
            <span class="glyph-badge" aria-hidden="true">
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
            <span class="flex-1 min-w-0">
              <span class="row-title !font-normal">{way.title}</span>
              <span class="block italic text-base text-ink-muted leading-snug">{way.detail}</span>
              <span class="row-fact !text-sky">{PrayLinks.summary(way.form, @choices)}</span>
            </span>
            <span class="hero-chevron-right size-5 row-chevron" aria-hidden="true" />
          </.link>
        </li>
      </ul>
    </section>
    """
  end
end
