defmodule LumenViaeWeb.Components.SetPortrait do
  @moduledoc """
  A meditation set's picture in the arch every set shares (`.arch-thumb`):
  the set's own painting, else its author's portrait, else a small gilt
  cross. The home page's rows and the category page's cards both use it,
  so a set looks the same wherever it is offered.
  """
  use Phoenix.Component

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork
  alias LumenViaeWeb.Components.ArtworkPicture

  attr :set, :map,
    required: true,
    doc: "a set loaded with its author, as the visible reads load it"

  attr :sizes, :string, required: true
  attr :class, :string, default: nil, doc: "the arch's size, such as \"w-16 h-20\""

  def set_portrait(assigns) do
    assigns = assign(assigns, :artwork, Rosary.artwork_record(assigns.set))

    ~H"""
    <span class={["arch-thumb", @class]}>
      <%= if @artwork do %>
        <ArtworkPicture.artwork_picture
          record={@artwork}
          alt={@artwork.image_alt}
          sizes={@sizes}
          class="absolute inset-0 w-full h-full object-cover"
          style={"object-position: #{Artwork.object_position(@artwork.image_focal_x, @artwork.image_focal_y)}"}
        />
      <% else %>
        <span class="absolute inset-0 flex items-center justify-center text-gilt" aria-hidden="true">
          <svg viewBox="0 0 10 14" class="w-3.5 h-5 fill-current">
            <path d="M3.6 0 H6.4 V2.8 H10 V5.6 H6.4 V14 H3.6 V5.6 H0 V2.8 H3.6 Z" />
          </svg>
        </span>
      <% end %>
    </span>
    """
  end
end
