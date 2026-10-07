defmodule LumenViaeWeb.ErrorHTML do
  @moduledoc """
  The public site's error pages, for HTML requests (see config/config.exs).

  404 and 500 are whole documents in the site's style: errors render with
  no layout, and a 500 must not lean on anything that may be what failed -
  no session, no CSRF token, no database, no LiveView. Every other status
  falls back to its plain status message.
  """
  use LumenViaeWeb, :html

  embed_templates "error_html/*"

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  attr :status, :integer, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  def error_page(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <meta name="theme-color" content="#003b5c" />
        <meta name="robots" content="noindex" />
        <title>{@title} - Lumen Viae</title>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link
          href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,500;1,400&family=Cinzel:wght@400;600&family=Cinzel+Decorative:wght@700&display=swap"
          rel="stylesheet"
        />
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body class="site bg-parchment min-h-dvh flex flex-col">
        <header class="site-header bg-navy border-b-2 border-gold">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 py-3 md:py-5">
            <a
              href="/"
              class="inline-flex items-center min-h-11 font-cinzel-decorative text-gold text-xl md:text-3xl tracking-widest font-bold"
            >
              LUMEN VIAE
            </a>
          </div>
        </header>

        <main id="main-content" class="flex-1 flex items-center">
          <div class="max-w-xl mx-auto px-6 py-16 md:py-24 text-center">
            <p class="font-cinzel text-gold-dark text-xs tracking-[0.4em] uppercase">
              {@status}
            </p>
            <.sacred_divider class="max-w-[210px] mx-auto my-6" />
            <h1 class="font-cinzel text-navy text-3xl md:text-5xl mb-5">{@title}</h1>
            <div class="font-garamond text-brown text-lg md:text-xl leading-relaxed">
              {render_slot(@inner_block)}
            </div>

            <nav class="mt-10 flex flex-wrap justify-center gap-3" aria-label="Where to go">
              <a href="/" class="btn-gold">Today's Rosary</a>
              <a href="/mysteries" class="btn-outline-gold text-navy">The Mysteries</a>
            </nav>
          </div>
        </main>

        <footer class="site-footer bg-cream border-t border-gold/30 py-8 text-center">
          <p class="font-cinzel text-gold-dark text-xs tracking-[0.25em] uppercase">
            Ad Majorem Dei Gloriam
          </p>
        </footer>
      </body>
    </html>
    """
  end
end
