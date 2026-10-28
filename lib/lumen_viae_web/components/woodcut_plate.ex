defmodule LumenViaeWeb.Components.WoodcutPlate do
  @moduledoc """
  A public-domain woodcut or engraving for one mystery of the Rosary, mounted
  as a plate with its caption.

  The plates come from `priv/static/images/woodcuts/manifest.json`, read when
  this module compiles. Editing the manifest, or adding or removing a file in
  that directory, recompiles it. A plate whose manifest entry lists WebP
  variants is served through `<picture>`, with the JPEG as the fallback.

  Import it where it is used; it is deliberately not in `html_helpers`.

      import LumenViaeWeb.Components.WoodcutPlate

      <.woodcut_plate key="sorrowful_1" />
      <.woodcut_plate key={@mystery.key} size={:sm} caption={false} />
      <.woodcut_plate key="glorious_5" variant={:vellum} />

  A key with no plate renders nothing, so a page can ask for every mystery and
  show the ones that exist. `keys/0` and `plate/1` say which those are.
  """
  use Phoenix.Component

  alias LumenViaeWeb.Components.WoodcutPlate.Manifest

  @dir Path.expand("../../../priv/static/images/woodcuts", __DIR__)
  @external_resource Path.join(@dir, "manifest.json")

  @plates Manifest.load(@dir, "/images/woodcuts")
  @listing Manifest.listing(@dir)

  @doc false
  def __mix_recompile__?, do: Manifest.listing(@dir) != @listing

  @sizes %{
    sm: "(min-width: 768px) 14rem, 11rem",
    md: "(min-width: 768px) 20rem, 80vw",
    lg: "(min-width: 1024px) 28rem, 90vw"
  }

  @doc "The plate for a mystery key, or nil when there is none."
  def plate(key)

  for {key, plate} <- @plates do
    def plate(unquote(key)), do: unquote(Macro.escape(plate))
  end

  def plate(_key), do: nil

  @keys @plates |> Map.keys() |> Enum.sort()

  @doc "Every mystery key that has a plate, sorted."
  def keys, do: @keys

  @category_keys %{
    "joyful" => "joyful_1",
    "sorrowful" => "sorrowful_5",
    "glorious" => "glorious_1",
    "luminous" => "luminous_1",
    "seven_sorrows" => "seven_sorrows_6"
  }

  @doc """
  The key of the plate that stands for a whole category, where its own
  painting is not published: the Annunciation, the Crucifixion, the
  Resurrection, the Baptism and the Lamentation. The same prints head the
  categories on the mysteries in Scripture page.
  """
  def category_key(category), do: Map.get(@category_keys, category)

  @doc """
  A plate's scan alone, as a `<picture>` with no mount or caption, for a
  card that crops it (`class` sets the crop). Renders nothing for a key
  with no plate.
  """
  attr :key, :string, required: true
  attr :class, :any, default: nil
  attr :sizes, :string, required: true

  def plate_picture(assigns) do
    assigns = assign(assigns, :plate, plate(assigns.key))

    ~H"""
    <picture :if={@plate}>
      <source :for={s <- @plate.sources} type={s.type} srcset={s.srcset} sizes={@sizes} />
      <img
        src={@plate.src}
        alt={@plate.alt}
        width={@plate.width}
        height={@plate.height}
        loading="lazy"
        decoding="async"
        class={@class}
      />
    </picture>
    """
  end

  @doc """
  The plate for a mystery, mounted with its caption. Renders nothing for a
  key with no plate.

  `size` sets the plate's width and the `sizes` hint for its sources. The default variant is for
  the night pages: the plate keeps its own paper on a vellum mat rather
  than being inverted or blended into the dark. `variant={:vellum}` is for
  a plate set on a vellum reading page, its paper multiplied into the mat.
  """
  attr :key, :string, required: true, doc: "a mystery key, such as \"sorrowful_1\""
  attr :class, :any, default: nil
  attr :caption, :boolean, default: true
  attr :size, :atom, values: [:sm, :md, :lg], default: :md
  attr :variant, :atom, values: [:night, :vellum], default: :night

  def woodcut_plate(assigns) do
    assigns = assign(assigns, :plate, plate(assigns.key))

    ~H"""
    <.plate_figure
      :if={@plate}
      plate={@plate}
      class={@class}
      caption={@caption}
      size={@size}
      variant={@variant}
    />
    """
  end

  @doc """
  Renders a plate already in hand, as `plate/1` returns it. Pages use
  `woodcut_plate/1`.
  """
  attr :plate, :map, required: true
  attr :class, :any, default: nil
  attr :caption, :boolean, default: true
  attr :size, :atom, values: [:sm, :md, :lg], default: :md
  attr :variant, :atom, values: [:night, :vellum], default: :night

  def plate_figure(assigns) do
    assigns = assign(assigns, :sizes, Map.fetch!(@sizes, assigns.size))

    ~H"""
    <figure class={[
      "woodcut-plate",
      "woodcut-plate--#{@size}",
      "woodcut-plate--#{@variant}",
      @class
    ]}>
      <div class="woodcut-plate__mount">
        <picture :if={@plate.sources != []}>
          <source :for={s <- @plate.sources} type={s.type} srcset={s.srcset} sizes={@sizes} />
          <.plate_img plate={@plate} />
        </picture>
        <.plate_img :if={@plate.sources == []} plate={@plate} />
      </div>
      <figcaption :if={@caption} class="woodcut-plate__caption">
        <span class="woodcut-plate__title">{@plate.title}</span>
        <span class="woodcut-plate__credit">
          {@plate.artist}<span :if={@plate.year}>, {@plate.year}</span>
        </span>
        <span :if={@plate.series} class="woodcut-plate__series">{@plate.series}</span>
        <a
          :if={@plate.source}
          href={@plate.source}
          class="woodcut-plate__source"
          rel="noopener"
          target="_blank"
        >
          Wikimedia Commons<span class="sr-only">: source and licence of {@plate.title}</span>
        </a>
      </figcaption>
    </figure>
    """
  end

  attr :plate, :map, required: true

  defp plate_img(assigns) do
    ~H"""
    <img
      src={@plate.src}
      alt={@plate.alt}
      width={@plate.width}
      height={@plate.height}
      loading="lazy"
      decoding="async"
      class="woodcut-plate__image"
    />
    """
  end
end
