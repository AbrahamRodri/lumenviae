defmodule LumenViaeWeb.Live.Home.CategoryCard do
  @moduledoc """
  One category on the home page's grid, as the app's "all mysteries" shows
  it: the card's painting, the category's name, what its mysteries are
  about, and the days it is prayed. A category with no published painting
  shows its numeral instead.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.ArtworkPicture

  attr :category, :map, required: true
  attr :today?, :boolean, default: false

  def category_card(assigns) do
    ~H"""
    <.link
      navigate={@category.path}
      class={[
        "home-card group flex flex-col h-full overflow-hidden rounded-2xl bg-white border transition-all duration-300 hover:-translate-y-1 hover:shadow-ornate",
        @today? && "border-gold shadow-ornate ring-1 ring-gold",
        !@today? && "border-gold/30 shadow-soft"
      ]}
    >
      <div class="relative aspect-[4/5] overflow-hidden bg-cream-dark">
        <ArtworkPicture.artwork_picture
          :if={@category.painting}
          record={@category.painting.record}
          alt={@category.painting.alt}
          sizes="(min-width: 1024px) 215px, (min-width: 768px) 31vw, 47vw"
          class="absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-[1.03]"
          style={"object-position: #{@category.painting.position}"}
        />
        <span
          :if={!@category.painting}
          class="absolute inset-0 flex items-center justify-center font-cinzel text-6xl text-gold-dark/60"
          aria-hidden="true"
        >
          {@category.numeral}
        </span>
        <span
          :if={@today?}
          class="absolute top-3 left-3 font-cinzel text-[0.7rem] tracking-[0.2em] uppercase text-navy-dark bg-gold-light px-3 py-1 rounded-full"
        >
          Today
        </span>
      </div>
      <div class="flex flex-col grow p-4 md:p-5">
        <h3 class="font-cinzel text-lg md:text-xl text-navy leading-tight mb-1 group-hover:text-gold-dark transition-colors">
          {@category.name}
        </h3>
        <p class="font-garamond text-base text-brown leading-snug mb-2">
          {@category.subtitle}
        </p>
        <p class="font-garamond italic text-sm text-brown-light leading-snug mt-auto">
          {@category.days}
        </p>
      </div>
    </.link>
    """
  end
end
