defmodule LumenViaeWeb.Live.Mysteries.CategoryList.Header do
  @moduledoc """
  The category page's hero (painting or woodcut, name, the days it is prayed)
  and, beneath it, its mysteries with the fruit each is prayed for.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.WoodcutPlate

  attr :category, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :days, :string, required: true
  attr :painting, :map, default: nil, doc: "the published painting, or nil for the woodcut"

  def category_hero(assigns) do
    ~H"""
    <section
      class="relative bg-night-deep overflow-hidden border-b border-night-border"
      aria-labelledby="category-heading"
    >
      <div class="absolute inset-0 opacity-[0.05]" aria-hidden="true">
        <picture class="contents">
          <source
            type="image/webp"
            srcset="/images/ornate-blue-gold-bg-symbols-480.webp 480w, /images/ornate-blue-gold-bg-symbols-735.webp 735w"
            sizes="100vw"
          />
          <img
            src="/images/ornate-blue-gold-bg-symbols.jpg"
            width="735"
            height="489"
            alt=""
            class="w-full h-full object-cover"
          />
        </picture>
      </div>

      <%!-- On a phone the picture sits beside the title, so the first
            screen reaches the mysteries. --%>
      <div class="relative max-w-5xl mx-auto px-4 sm:px-8 py-6 md:py-14 grid grid-cols-[6rem_minmax(0,1fr)] sm:grid-cols-[9rem_minmax(0,1fr)] md:grid-cols-[14rem_minmax(0,1fr)] gap-4 sm:gap-8 md:gap-12 items-center">
        <.arch_frame
          :if={@painting}
          src={@painting.src}
          alt={@painting.alt}
          class="w-full category-rise"
          img_class={focal_class(@category)}
        />
        <WoodcutPlate.woodcut_plate
          :if={!@painting}
          key={WoodcutPlate.category_key(@category)}
          size={:sm}
          caption={false}
          class="category-plate category-rise"
        />

        <div class="min-w-0">
          <p class="kicker mb-1">The Holy Rosary</p>
          <h1
            id="category-heading"
            class="font-display text-[2rem] sm:text-5xl md:text-6xl text-ink-light leading-[1.05] mb-1 sm:mb-2"
          >
            {@title}
          </h1>
          <p class="hidden sm:block font-garamond italic text-xl text-ink-muted mb-3">{@subtitle}</p>
          <p class="font-garamond italic text-base sm:text-lg text-ink-muted" data-role="days">
            <span class="sr-only">Prayed on </span>{@days}
          </p>
        </div>
      </div>
    </section>
    """
  end

  # The part of the painting kept in view, as the app's card keeps it
  # (Categories.card_focal_point/1). Literal classes, so Tailwind sees them.
  defp focal_class("glorious"), do: "object-[50%_22%]"
  defp focal_class("seven_sorrows"), do: "object-[50%_30%]"
  defp focal_class(_category), do: "object-center"

  attr :category, :string, required: true
  attr :mysteries, :list, required: true

  def mysteries_list(assigns) do
    ~H"""
    <section class="max-w-5xl mx-auto px-4 sm:px-8 pt-8 md:pt-12" aria-labelledby="mysteries-heading">
      <h2 id="mysteries-heading" class="section-label">
        {if @category == "seven_sorrows", do: "The Seven Sorrows", else: "The Mysteries"}
      </h2>
      <ol class="grid gap-x-10 sm:grid-cols-2 border-t border-night-border">
        <li
          :for={mystery <- @mysteries}
          class="flex items-baseline gap-3 py-2.5 border-b border-night-border"
        >
          <span class="font-display text-gilt text-lg w-8 shrink-0" aria-hidden="true">
            {roman(mystery.order)}
          </span>
          <p class="min-w-0 font-garamond text-lg text-ink-light leading-snug">
            {mystery.name || mystery.label}<span
              :if={mystery.fruit}
              class="italic text-base text-ink-muted"
            ><span aria-hidden="true"> &middot; </span><span class="sr-only">. Fruit: </span>{mystery.fruit}</span>
          </p>
        </li>
      </ol>
    </section>
    """
  end

  defp roman(n), do: Enum.at(~w(I II III IV V VI VII), n - 1)
end
