defmodule LumenViaeWeb.Live.Home.CategoryCard do
  @moduledoc """
  One category on the home page's grid, as the app's mystery card draws
  it: the painting full-bleed (`.paint-tile`), the category's name in
  Cinzel on it and the days it is prayed. The wide card (the odd one out
  on a phone) also says what its mysteries are about. A category with no published painting
  shows its woodcut instead (`WoodcutPlate.category_key/1`).
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.{ArtworkPicture, WoodcutPlate}

  attr :category, :map, required: true
  attr :today?, :boolean, default: false
  attr :wide?, :boolean, default: false, doc: "a phone's whole row"

  def category_card(assigns) do
    assigns = assign(assigns, :woodcut, WoodcutPlate.category_key(assigns.category.slug))

    ~H"""
    <.link
      navigate={@category.path}
      class={[
        "home-card paint-tile h-40 md:h-56",
        @today? && "paint-tile--today"
      ]}
    >
      <ArtworkPicture.artwork_picture
        :if={@category.painting}
        record={@category.painting.record}
        alt={@category.painting.alt}
        sizes="(min-width: 1024px) 215px, (min-width: 768px) 31vw, 47vw"
        class="paint-tile__image"
        style={"object-position: #{@category.painting.position}"}
      />
      <WoodcutPlate.plate_picture
        :if={!@category.painting && @woodcut}
        key={@woodcut}
        sizes="(min-width: 1024px) 215px, (min-width: 768px) 31vw, 47vw"
        class={["paint-tile__image paint-tile__image--woodcut", woodcut_position(@wide?)]}
      />
      <span class="paint-tile__arrow" aria-hidden="true">
        <span class="hero-arrow-right size-3.5" />
      </span>
      <div class="paint-tile__words">
        <span :if={@today?} class="badge-capsule mb-1.5">Today</span>
        <h3 class="paint-tile__title">{@category.name}</h3>
        <span class="paint-tile__line">{if @wide?, do: @category.subtitle, else: @category.days}</span>
        <span :if={@wide?} class="paint-tile__line">{@category.days}</span>
      </div>
    </.link>
    """
  end

  # A woodcut's subject sits high; the wide tile shows a band across it.
  defp woodcut_position(true), do: "object-[50%_35%]"
  defp woodcut_position(false), do: "object-[50%_25%]"
end
