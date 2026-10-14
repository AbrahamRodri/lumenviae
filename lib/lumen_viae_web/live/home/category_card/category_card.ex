defmodule LumenViaeWeb.Live.Home.CategoryCard do
  @moduledoc """
  One category on the home page's grid, as the app's "all mysteries" shows
  it: the card's painting, the category's name and the days it is prayed.
  The wide card (the odd one out on a phone) also says what its mysteries
  are about. A category with no published painting
  shows its woodcut instead (`WoodcutPlate.category_key/1`).
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.{ArtworkPicture, WoodcutPlate}

  attr :category, :map, required: true
  attr :today?, :boolean, default: false
  attr :wide?, :boolean, default: false, doc: "a phone's whole row: the picture beside the words"

  def category_card(assigns) do
    assigns = assign(assigns, :woodcut, WoodcutPlate.category_key(assigns.category.slug))

    ~H"""
    <.link
      navigate={@category.path}
      class={[
        "home-card group flex h-full overflow-hidden rounded-2xl bg-night-raised border transition-colors duration-300",
        if(@wide?, do: "max-md:flex-row flex-col", else: "flex-col"),
        @today? && "border-gilt ring-1 ring-gilt",
        !@today? && "border-night-border hover:border-night-line"
      ]}
    >
      <div class={[
        "relative overflow-hidden bg-vellum",
        if(@wide?,
          do: "aspect-[4/3] max-md:aspect-auto max-md:w-[46%] shrink-0",
          else: "aspect-[4/3]"
        )
      ]}>
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
          class="absolute inset-0 w-full h-full object-cover object-[50%_30%] transition-transform duration-500 group-hover:scale-[1.03]"
        />
      </div>
      <div class="flex flex-col grow gap-0.5 px-3.5 pt-3 pb-3.5 md:px-4 md:pb-4 min-w-0">
        <span
          :if={@today?}
          class="self-start font-garamond text-sm font-semibold text-night bg-gilt px-2.5 rounded-full mb-1"
        >
          Today
        </span>
        <h3 class="font-display text-xl md:text-2xl font-semibold text-ink-light leading-tight group-hover:text-gilt transition-colors break-words">
          {@category.name}
        </h3>
        <p :if={@wide?} class="md:hidden font-garamond text-base text-ink-muted leading-snug">
          {@category.subtitle}
        </p>
        <p class="font-garamond italic text-sm text-ink-muted leading-snug mt-auto pt-1">
          {@category.days}
        </p>
      </div>
    </.link>
    """
  end
end
