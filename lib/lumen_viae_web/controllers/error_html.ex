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
        <meta name="theme-color" content="#070E1F" />
        <meta name="robots" content="noindex" />
        <title>{@title} - Lumen Viae</title>
        <link rel="icon" href="/favicon.ico" sizes="32x32" />
        <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body class="site bg-night text-ink-light min-h-dvh flex flex-col">
        <header class="site-header bg-night-deep border-b border-night-border">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 py-2 md:py-4">
            <a
              href="/"
              class="inline-flex items-center gap-2.5 min-h-11 font-display font-semibold text-ink-light text-2xl md:text-[1.75rem]"
            >
              <.logo /> Lumen Viae
            </a>
          </div>
        </header>

        <main id="main-content" class="flex-1 flex items-center">
          <div class="max-w-xl mx-auto px-6 py-16 md:py-24 text-center">
            <p class="kicker">
              {@status}
            </p>
            <.sacred_divider class="max-w-[210px] mx-auto my-6" />
            <h1 class="font-display text-ink-light text-5xl md:text-6xl mb-5">{@title}</h1>
            <div class="font-garamond text-ink-muted text-lg md:text-xl leading-relaxed">
              {render_slot(@inner_block)}
            </div>

            <nav class="mt-10 flex flex-wrap justify-center gap-3" aria-label="Where to go">
              <a href="/" class="btn-gold">Today's Rosary</a>
              <a href="/mysteries" class="btn-outline-gold">The Mysteries</a>
            </nav>
          </div>
        </main>

        <footer class="site-footer bg-night-deep border-t border-night-border py-8 text-center">
          <p class="kicker">
            Ad Majorem Dei Gloriam
          </p>
        </footer>
      </body>
    </html>
    """
  end
end
