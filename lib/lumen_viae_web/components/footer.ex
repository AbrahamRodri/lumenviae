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
    <footer class="relative bg-navy text-gold text-center py-12 border-t-3 border-gold overflow-hidden">
      <div class="absolute inset-0 opacity-[0.04]" aria-hidden="true">
        <img
          src="/images/ornate-blue-gold-bg-symbols.jpg"
          alt=""
          class="w-full h-full object-cover"
        />
      </div>

      <div class="relative">
        <!-- Crucifix at Top -->
        <div class="mx-auto px-8">
          <.medallion type="crucifix" size="medium" />
        </div>

        <!-- Site navigation -->
        <nav
          class="mt-10 flex flex-wrap justify-center gap-x-8 gap-y-3 px-8"
          aria-label="Footer navigation"
        >
          <.footer_link navigate="/">Home</.footer_link>
          <.footer_link navigate="/mysteries">Scripture of the Rosary</.footer_link>
          <.footer_link navigate="/rosary-methods">Rosary Methods</.footer_link>
          <.footer_link navigate="/app">The App</.footer_link>
          <.footer_link navigate="/feedback">Feedback</.footer_link>
          <.footer_link navigate="/privacy-policy">Privacy Policy</.footer_link>
        </nav>

        <div class="mt-6">
          <.ornate_divider variant="white" class="my-8 opacity-20 max-w-sm mx-auto" />

          <p class="font-garamond text-gold-light text-base tracking-wide italic">
            Lumen Viae - Light of the Way
          </p>
          <p class="font-garamond text-gold opacity-70 text-sm mt-2">
            &copy; {Date.utc_today().year} All Rights Reserved
          </p>
          <p class="font-cinzel text-gold text-sm tracking-widest uppercase mt-3">
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
      class="font-work-sans text-sm text-gold-light/80 hover:text-gold transition-colors"
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
