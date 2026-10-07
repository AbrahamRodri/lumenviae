defmodule LumenViaeWeb.Live.Home.CategoryCard do
  @moduledoc """
  One category on the home page's grid, as the app's "all mysteries" shows
  it: the card's painting, the category's name, what its mysteries are
  about, and the days it is prayed. A category with no published painting
  shows its woodcut instead (`WoodcutPlate.category_key/1`).
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.{ArtworkPicture, WoodcutPlate}

  attr :category, :map, required: true
  attr :today?, :boolean, default: false

  def category_card(assigns) do
    assigns = assign(assigns, :woodcut, WoodcutPlate.category_key(assigns.category.slug))

    ~H"""
    <.link
      navigate={@category.path}
      class={[
        "home-card group flex flex-col h-full overflow-hidden rounded-2xl bg-night-raised border transition-all duration-300 hover:-translate-y-1 hover:shadow-night",
        @today? && "border-gilt ring-1 ring-gilt",
        !@today? && "border-night-border hover:border-night-line"
      ]}
    >
      <div class="relative aspect-[4/5] overflow-hidden bg-vellum">
        <ArtworkPicture.artwork_picture
          :if={@category.painting}
          record={@category.painting.record}
          alt={@category.painting.alt}
          sizes="(min-width: 1024px) 215px, (min-width: 768px) 31vw, 47vw"
          class="absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-[1.03]"
          style={"object-position: #{@category.painting.position}"}
        />
        <WoodcutPlate.plate_picture
          :if={!@category.painting && @woodcut}
          key={@woodcut}
          sizes="(min-width: 1024px) 215px, (min-width: 768px) 31vw, 47vw"
          class="absolute inset-0 w-full h-full object-cover object-top transition-transform duration-500 group-hover:scale-[1.03]"
        />
        <span
          :if={@today?}
          class="absolute top-2.5 left-2.5 max-w-[calc(100%-1.25rem)] font-garamond text-sm font-semibold text-night bg-gilt px-3 py-0.5 rounded-full"
        >
          Today
        </span>
      </div>
      <div class="flex flex-col grow p-4 md:p-5 min-w-0">
        <h3 class="font-display text-xl md:text-2xl font-semibold text-ink-light leading-tight mb-1 group-hover:text-gilt transition-colors break-words">
          {@category.name}
        </h3>
        <p class="font-garamond text-base text-ink-muted leading-snug mb-2">
          {@category.subtitle}
        </p>
        <p class="font-garamond italic text-sm text-ink-muted leading-snug mt-auto">
          {@category.days}
        </p>
      </div>
    </.link>
    """
  end
end
