defmodule LumenViaeWeb.Components.Footer do
  @moduledoc """
  The public site's footer: one row of the site's links and the colophon.
  The mysteries themselves are in the header's menu.
  """
  use Phoenix.Component

  @doc """
  Renders the site footer.
  """
  def footer(assigns) do
    ~H"""
    <footer
      id="site-footer"
      class="site-footer bg-night-deep text-center border-t border-night-border"
    >
      <div class="max-w-3xl mx-auto px-4 sm:px-8 py-8">
        <nav aria-label="Footer">
          <ul class="flex flex-wrap justify-center gap-x-2 sm:gap-x-4">
            <li><.footer_link navigate="/">Today's Rosary</.footer_link></li>
            <li><.footer_link navigate="/mysteries">Mysteries</.footer_link></li>
            <li><.footer_link navigate="/app">The App</.footer_link></li>
            <li><.footer_link navigate="/privacy-policy">Privacy</.footer_link></li>
          </ul>
        </nav>

        <p class="font-garamond text-ink-muted text-base mt-3">
          &copy; {Date.utc_today().year} Lumen Viae
          <span aria-hidden="true" class="mx-1.5">&middot;</span>
          <span lang="la">Ad Majorem Dei Gloriam</span>
        </p>
      </div>
    </footer>
    """
  end

  attr :navigate, :string, required: true
  slot :inner_block, required: true

  defp footer_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="inline-flex items-center min-h-11 px-2 font-garamond text-lg text-ink-light underline-offset-4 decoration-gilt hover:text-gilt hover:underline transition-colors"
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
