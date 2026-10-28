defmodule LumenViaeWeb.Components.ArtworkPicture do
  @moduledoc """
  An uploaded painting on the public site, drawn from its WebP display
  variants where it has them, so a phone fetches a few dozen kilobytes
  rather than a several-megabyte original.

  The variants offered are only the ones recorded as stored
  (`LumenViae.Rosary.artwork_variant_urls/1`), followed by the original at
  its own width. A painting with none
  renders exactly the plain `<img>` it always did, and the original stays
  the `<img>`'s own `src` either way, so a browser without WebP, or a
  painting not yet backfilled, still shows the painting and never a broken
  image.

  `sizes` must describe how wide the image is drawn, in CSS pixels, at
  each breakpoint of the page that uses it: the browser picks a variant
  from it before layout, so an understated value is what would make a
  painting soft.
  """
  use Phoenix.Component

  alias LumenViae.Rosary

  attr :record, :map, required: true, doc: "the record carrying the painting"
  attr :alt, :string, required: true
  attr :sizes, :string, required: true, doc: "the rendered width at each breakpoint"
  attr :class, :any, default: nil
  attr :style, :string, default: nil

  def artwork_picture(assigns) do
    variants = Rosary.artwork_variant_urls(assigns.record)
    src = Rosary.artwork_url(assigns.record)

    assigns =
      assigns
      |> assign(:src, src)
      |> assign(:srcset, srcset(variants, src, assigns.record.image_width))
      |> assign(:width, assigns.record.image_width)
      |> assign(:height, assigns.record.image_height)

    ~H"""
    <%= if @srcset do %>
      <picture>
        <source type="image/webp" srcset={@srcset} sizes={@sizes} />
        <.img src={@src} alt={@alt} width={@width} height={@height} class={@class} style={@style} />
      </picture>
    <% else %>
      <.img src={@src} alt={@alt} width={@width} height={@height} class={@class} style={@style} />
    <% end %>
    """
  end

  attr :src, :string, required: true
  attr :alt, :string, required: true
  attr :width, :integer, default: nil
  attr :height, :integer, default: nil
  attr :class, :any, default: nil
  attr :style, :string, default: nil

  # The intrinsic width and height reserve the box before the image loads;
  # every caller's CSS sets the drawn size, so they never stretch it.
  defp img(assigns) do
    ~H"""
    <img
      src={@src}
      alt={@alt}
      width={@width}
      height={@height}
      loading="lazy"
      decoding="async"
      class={@class}
      style={@style}
    />
    """
  end

  defp srcset([], _original, _width), do: nil

  # The original closes the list at its own width, so a 2x screen can still
  # choose it when the variants stop short (a backfill that ran partway).
  # It sits in the WebP source though it may be a JPEG: `type` only says
  # whether the browser can read the source at all, and every browser that
  # reads WebP reads JPEG and PNG.
  defp srcset(variants, original, width) do
    widest = variants |> Enum.map(&elem(&1, 0)) |> Enum.max()

    candidates =
      if is_integer(width) and width > widest,
        do: variants ++ [{width, original}],
        else: variants

    Enum.map_join(candidates, ", ", fn {width, url} -> "#{url} #{width}w" end)
  end
end
