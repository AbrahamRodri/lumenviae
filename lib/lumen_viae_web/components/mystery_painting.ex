defmodule LumenViaeWeb.Components.MysteryPainting do
  @moduledoc """
  The iOS app's old-master paintings for the mysteries and the categories'
  cards, served as static WebP from `priv/static/images/paintings`, the same
  pictures the app bundles. A painting uploaded on a mystery or a card in the
  console wins over these; this is what a page shows until one is.

  The pictures and their credits come from `manifest.json` in that directory,
  read when this module compiles: `mysteries` maps a mystery key
  (`"joyful_1"`) to a painting, `cards` a category to the painting on its
  card (the four Rosaries' first mystery, the Seven Sorrows' Pieta), and
  `paintings` holds each picture's widths and its title, artist and date
  from the app's sourcing notes. Each painting is `<name>-480.webp`,
  `<name>-960.webp` (or its full width, when narrower) and a 480 pixel
  `<name>.jpg`. See docs/MYSTERY_PAINTINGS.md.

      <MysteryPainting.picture key="sorrowful_1" sizes="64px" class="..." />
      <MysteryPainting.picture category="glorious" sizes="50vw" class="..." />

  A key with no painting renders nothing.
  """
  use Phoenix.Component

  alias LumenViae.Rosary.Artwork
  alias LumenViaeWeb.Components.ArtworkPicture

  @dir Path.expand("../../../priv/static/images/paintings", __DIR__)
  @external_resource Path.join(@dir, "manifest.json")

  @manifest @dir |> Path.join("manifest.json") |> File.read!() |> Jason.decode!()

  @paintings Map.new(@manifest["paintings"], fn p ->
               [[w1, h1], [w2, h2]] = p["widths"]
               base = "/images/paintings/#{p["name"]}"

               credit =
                 [p["title"], p["artist"], p["date"]]
                 |> Enum.reject(&is_nil/1)
                 |> Enum.join(", ")

               alt =
                 case {p["title"], p["artist"]} do
                   {nil, _} -> "A painting of the mystery"
                   {title, nil} -> title
                   {title, artist} -> "#{title}, by #{artist}"
                 end

               {p["name"],
                %{
                  name: p["name"],
                  src: "#{base}.jpg",
                  srcset: "#{base}-480.webp #{w1}w, #{base}-960.webp #{w2}w",
                  width: w2,
                  height: h2,
                  small: {w1, h1},
                  title: p["title"],
                  artist: p["artist"],
                  date: p["date"],
                  credit: credit,
                  alt: alt
                }}
             end)

  @mysteries @manifest["mysteries"]
  @cards @manifest["cards"]

  @doc "The painting for a mystery key, such as \"glorious_3\", or nil."
  def for_mystery(key), do: @paintings[@mysteries[key]]

  @doc "The painting on a category's card, or nil."
  def for_category(slug), do: @paintings[@cards[slug]]

  @doc """
  A painting as a `<picture>`: WebP at two widths, the small JPEG as the
  fallback. Give `key` (a mystery) or `category`; `class` sets the crop.
  Give `record` (the mystery or card) too where it is at hand: a painting
  uploaded and published on it wins, drawn from its own variants.
  """
  attr :key, :string, default: nil
  attr :category, :string, default: nil
  attr :record, :any, default: nil, doc: "the mystery or category card, for an uploaded painting"
  attr :sizes, :string, required: true
  attr :class, :any, default: nil
  attr :style, :string, default: nil
  attr :alt, :string, default: nil, doc: "overrides the painting's own description"
  attr :loading, :string, default: "lazy"

  def picture(%{record: record} = assigns) when not is_nil(record) do
    if Artwork.publishable?(record) do
      ~H"""
      <ArtworkPicture.artwork_picture
        record={@record}
        alt={@alt || @record.image_alt}
        sizes={@sizes}
        class={@class}
        style={"object-position: #{Artwork.object_position(@record.image_focal_x, @record.image_focal_y)}"}
      />
      """
    else
      picture(%{assigns | record: nil})
    end
  end

  def picture(assigns) do
    painting = if assigns.key, do: for_mystery(assigns.key), else: for_category(assigns.category)
    assigns = assign(assigns, :painting, painting)

    ~H"""
    <picture :if={@painting}>
      <source type="image/webp" srcset={@painting.srcset} sizes={@sizes} />
      <img
        src={@painting.src}
        alt={@alt || @painting.alt}
        width={@painting.width}
        height={@painting.height}
        loading={@loading}
        decoding="async"
        class={@class}
        style={@style}
      />
    </picture>
    """
  end

  @doc """
  A category's painting framed, with its credit beneath: the title, the
  artist and the date. For a page that names the painting, as the
  mysteries in Scripture page does.
  """
  attr :category, :string, required: true
  attr :class, :any, default: nil

  def figure(assigns) do
    assigns = assign(assigns, :painting, for_category(assigns.category))

    ~H"""
    <figure :if={@painting} class={["painting-figure", @class]}>
      <div class="painting-frame">
        <.picture
          category={@category}
          sizes="(min-width: 768px) 14rem, 11rem"
          class="w-full h-full object-cover"
        />
      </div>
      <figcaption class="painting-figure__caption">
        <span class="painting-figure__title">{@painting.title}</span>
        <span :if={@painting.artist} class="painting-figure__credit">
          {@painting.artist}{if @painting.date, do: ", #{@painting.date}"}
        </span>
      </figcaption>
    </figure>
    """
  end
end
