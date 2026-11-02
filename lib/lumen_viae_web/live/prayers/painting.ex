defmodule LumenViaeWeb.Live.Prayers.Painting do
  @moduledoc """
  A Prayer Book painting (`LumenViaeWeb.Live.Prayers.Book`'s
  `{name, focal x, focal y}`) as an `<img>`, cropped about its subject.
  Decorative: every card and row that hangs one says its words beside it.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.MysteryPainting

  attr :painting, :any, required: true, doc: "`{name, focal x, focal y}`"
  attr :sizes, :string, required: true
  attr :class, :any, default: nil
  attr :loading, :string, default: "lazy"

  def painting(assigns) do
    {name, x, y} = assigns.painting

    assigns =
      assign(assigns,
        name: name,
        position: "object-position: #{round(x * 100)}% #{round(y * 100)}%"
      )

    ~H"""
    <MysteryPainting.picture
      name={@name}
      sizes={@sizes}
      alt=""
      class={@class}
      style={@position}
      loading={@loading}
    />
    """
  end
end
