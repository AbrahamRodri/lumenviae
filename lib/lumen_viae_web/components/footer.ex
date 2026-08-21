defmodule LumenViaeWeb.Components.Footer do
  @moduledoc """
  Footer component with ornate elements.
  """
  use Phoenix.Component
  import LumenViaeWeb.CoreComponents

  @doc """
  Renders the site footer with ornate decorations and site navigation.
  """
  def footer(assigns) do
    ~H"""
    <footer class="relative bg-cream text-center py-14 border-t border-gold/30">
      <div class="relative max-w-5xl mx-auto">
        <!-- Crucifix at Top -->
        <div class="mx-auto px-8">
          <.medallion type="crucifix" size="medium" />
        </div>
        
    <!-- Site navigation -->
        <nav
          class="mt-10 flex flex-wrap justify-center gap-x-8 gap-y-4 px-8"
          aria-label="Footer navigation"
        >
          <.footer_link navigate="/">Home</.footer_link>
          <.footer_link navigate="/rosary-methods">How to Pray the Rosary</.footer_link>
          <.footer_link navigate="/mysteries">Mysteries in Scripture</.footer_link>
          <.footer_link navigate="/true-devotion">True Devotion to Mary</.footer_link>
          <.footer_link navigate="/saint-carlo">St. Carlo Acutis</.footer_link>
          <.footer_link navigate="/app">The App</.footer_link>
          <.footer_link navigate="/feedback">Feedback</.footer_link>
          <.footer_link navigate="/privacy-policy">Privacy Policy</.footer_link>
        </nav>

        <div class="mt-6">
          <.sacred_divider class="my-8 max-w-sm mx-auto" />

          <p class="font-garamond text-brown text-lg tracking-wide italic">
            Lumen Viae - Light of the Way
          </p>
          <p class="font-garamond text-brown-light text-sm mt-2">
            &copy; {Date.utc_today().year} All Rights Reserved
          </p>
          <p class="font-cinzel text-gold-dark text-sm tracking-widest uppercase mt-3">
            Ad Majorem Dei Gloriam
          </p>
        </div>
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
      class="font-cinzel text-[0.7rem] tracking-[0.15em] uppercase text-gold-dark hover:text-gold transition-colors"
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
