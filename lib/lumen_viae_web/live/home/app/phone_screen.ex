defmodule LumenViaeWeb.Live.Home.App.PhoneScreen do
  @moduledoc """
  One screenshot of the iPhone app in a phone drawn in CSS (`.phone-frame`
  in `app.css`): a thin dark bezel with the screen's own rounded corners,
  no device photograph.

  A screenshot `name` is three files in `priv/static/images/app/`:
  `<name>-390.webp`, `<name>-780.webp` and the `<name>.jpg` fallback, 390
  pixels wide. All are cut from a 1206x2622 simulator capture, so every
  one has the same 390x848 shape.
  """
  use Phoenix.Component

  @width 390
  @height 848

  attr :name, :string,
    required: true,
    doc: "the screenshot's file name, without width or extension"

  attr :alt, :string, required: true, doc: "what the screen shows"
  attr :sizes, :string, default: "(min-width: 768px) 300px, 260px"
  attr :loading, :string, default: "lazy", values: ~w(lazy eager)
  attr :class, :any, default: nil

  def phone_screen(assigns) do
    assigns = assign(assigns, width: @width, height: @height)

    ~H"""
    <div class={["phone-frame", @class]}>
      <picture>
        <source
          type="image/webp"
          srcset={"/images/app/#{@name}-390.webp 390w, /images/app/#{@name}-780.webp 780w"}
          sizes={@sizes}
        />
        <img
          src={"/images/app/#{@name}.jpg"}
          width={@width}
          height={@height}
          alt={@alt}
          loading={@loading}
          decoding="async"
          class="phone-frame__screen"
        />
      </picture>
    </div>
    """
  end
end
