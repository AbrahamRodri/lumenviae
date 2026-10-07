defmodule LumenViaeWeb.Components.MetaTags do
  @moduledoc """
  The description, canonical link, Open Graph and Twitter tags and the
  structured data in the root layout's `<head>`, from what a page put in
  `LumenViaeWeb.PageMeta`.

  A page that put nothing gets the site's default description and image and
  the address it was asked for, so the tags are never missing; it is the
  public pages' job to say something more specific.
  """
  use Phoenix.Component

  alias LumenViaeWeb.PageMeta

  @default_description "Pray the traditional fifteen mysteries of the Holy Rosary with meditations from the saints and doctors of the Church. Guided audio, scripture, and the methods of St. Louis de Montfort."

  attr :meta, :map, default: nil, doc: "the page's `:meta` assign, if it set one"
  attr :page_title, :string, default: nil
  attr :description, :string, default: nil, doc: "a page's own `:meta_description`, if no `:meta`"
  attr :request_path, :string, required: true

  def meta_tags(assigns) do
    meta = assigns.meta || fallback(assigns)
    assigns = assign(assigns, :m, meta)

    ~H"""
    <meta name="description" content={@m.description} />
    <link rel="canonical" href={@m.url} />
    <meta property="og:site_name" content={PageMeta.site_name()} />
    <meta property="og:type" content={@m.type} />
    <meta property="og:title" content={@m.title} />
    <meta property="og:description" content={@m.description} />
    <meta property="og:url" content={@m.url} />
    <meta property="og:image" content={@m.image.url} />
    <meta property="og:image:width" content={@m.image.width} />
    <meta property="og:image:height" content={@m.image.height} />
    <meta property="og:image:alt" content={@m.image.alt} />
    <meta name="twitter:card" content={@m.card} />
    <meta name="twitter:title" content={@m.title} />
    <meta name="twitter:description" content={@m.description} />
    <meta name="twitter:image" content={@m.image.url} />
    <meta name="twitter:image:alt" content={@m.image.alt} />
    <%!-- HEEx leaves a script's body alone, so this is EEx; "<" in the JSON is
          escaped, so a name can never close the tag. --%>
    <script :for={data <- @m.json_ld} type="application/ld+json">
      <%= Phoenix.HTML.raw(Jason.encode!(data, escape: :html_safe)) %>
    </script>
    """
  end

  defp fallback(assigns) do
    PageMeta.build(assigns.request_path,
      title: assigns.page_title || "Lumen Viae - Meditations on the Holy Rosary",
      description: assigns.description || @default_description
    )
  end
end
