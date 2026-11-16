defmodule LumenViaeWeb.Live.Home.App.Index do
  @moduledoc """
  The iPhone app's landing page, at `/app`: design's direction C (Abraham,
  16 Nov 2026: "i like c the best"), in the Midnight colours. A painting
  leads with one phone, two painting-and-words rows follow, then six tiles
  and the closing call.

  Every phone is the app itself in its Midnight theme: a short silent loop
  where its clip is in `priv/static/images/app/clips/`, else its still
  (`LumenViaeWeb.Live.Home.App.Clip`). The counts are the library's own,
  read when the page mounts, so they stay true.

  `?lang=es` is the page in Spanish, linked from nowhere yet and kept out
  of search engines until it is. See docs/PUBLIC_SITE.md, "The app page".
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Rosary
  alias LumenViaeWeb.Live.Home.App.Words
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Home.App.Clip

  @impl true
  def mount(params, _session, socket) do
    lang = if params["lang"] == "es", do: :es, else: :en
    counts = counts(socket.assigns[:current_admin])
    t = Words.for(lang, counts)

    {:ok,
     socket
     |> PageMeta.put("/app",
       title: t.title,
       description: t.description,
       image: %{
         url: PageMeta.absolute_url("/images/app/og-app.jpg"),
         width: 1200,
         height: 630,
         alt: t.og_alt
       },
       json_ld: [PageMeta.mobile_app()],
       noindex: lang == :es
     )
     |> assign(app_store_url: PageMeta.app_store_url(), lang: lang, t: t)}
  end

  # The library's own counts: what the app carries, read from the documents
  # it is served.
  defp counts(actor) do
    %{
      chants: length(Rosary.get_chant_library!(actor: actor, load: [:chants]).chants),
      prayers: length(Rosary.get_prayer_book!(actor: actor, load: [:prayers]).prayers)
    }
  end

  # The download link: Apple's own "Download on the App Store" badge (black,
  # US English, from developer.apple.com), kept as downloaded. Apple's rules:
  # never recoloured, cropped or given effects, at least 40 px tall, with
  # clear space of a quarter of its height around it.
  attr :href, :string, required: true
  attr :free, :string, required: true

  defp app_store_button(assigns) do
    ~H"""
    <div class="app-badge">
      <a href={@href} class="inline-block shrink-0" rel="noopener">
        <img
          src={~p"/images/app/app-store-badge.svg"}
          alt="Download on the App Store"
          width="168"
          height="56"
          class="h-14 w-auto"
        />
      </a>
      <span class="app-badge__free">{@free}</span>
    </div>
    """
  end
end
