defmodule LumenViaeWeb.Live.Mysteries.CategoryList.Header do
  @moduledoc """
  The category page's head (its painting beside the name, the days
  it is prayed), as the app heads a pushed page, and beneath it its
  mysteries with the fruit each is prayed for.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.MysteryPainting

  attr :category, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :days, :string, required: true
  attr :painting, :map, default: nil, doc: "the uploaded painting, or nil for the app's own"

  def category_hero(assigns) do
    ~H"""
    <section
      class="border-b border-[rgba(227,188,91,0.15)]"
      aria-labelledby="category-heading"
    >
      <%!-- As the app heads a pushed page: the picture beside the title in
            Cinzel, the days in tracked gold capitals. --%>
      <div class="max-w-5xl mx-auto px-4 sm:px-8 py-5 md:py-10 grid grid-cols-[4.5rem_minmax(0,1fr)] sm:grid-cols-[7rem_minmax(0,1fr)] md:grid-cols-[10rem_minmax(0,1fr)] gap-4 sm:gap-6 md:gap-10 items-center">
        <.arch_frame
          :if={@painting}
          src={@painting.src}
          alt={@painting.alt}
          class="w-full category-rise"
          img_class={focal_class(@category)}
        />
        <div :if={!@painting} class="painting-frame category-rise">
          <MysteryPainting.picture
            category={@category}
            sizes="(min-width: 768px) 160px, (min-width: 640px) 112px, 72px"
            loading="eager"
            class="w-full h-full object-cover"
          />
        </div>

        <div class="min-w-0">
          <p class="kicker hidden sm:block mb-1">The Holy Rosary</p>
          <h1
            id="category-heading"
            class="font-display text-[1.5rem] sm:text-4xl md:text-5xl text-ink-light leading-[1.1] mb-1 sm:mb-2"
          >
            {@title}
          </h1>
          <p class="hidden sm:block font-garamond italic text-lg text-ink-muted mb-1">{@subtitle}</p>
          <p class="kicker" data-role="days">
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
      <ol class="mystery-ledger grid gap-x-10 sm:grid-cols-2">
        <li :for={mystery <- @mysteries}>
          <span class="mystery-ledger__numeral" aria-hidden="true">{roman(mystery.order)}</span>
          <span class="mystery-thumb" aria-hidden="true">
            <MysteryPainting.picture
              key={mystery.key}
              record={mystery.record}
              sizes="44px"
              alt=""
              class="w-full h-full object-cover"
            />
          </span>
          <p class="min-w-0">
            <span class="block text-lg text-ink-light leading-snug">
              {mystery.name || mystery.label}
            </span>
            <span :if={mystery.fruit} class="block italic text-base text-ink-muted">
              <span class="sr-only">Fruit: </span>{mystery.fruit}
            </span>
          </p>
        </li>
      </ol>
    </section>
    """
  end

  defp roman(n), do: Enum.at(~w(I II III IV V VI VII), n - 1)
end
