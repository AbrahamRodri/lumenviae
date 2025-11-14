defmodule LumenViaeWeb.Components.Footer do
  @moduledoc """
  Footer component with ornate elements.
  """
  use Phoenix.Component
  import LumenViaeWeb.CoreComponents

  @doc """
  Renders the site footer with ornate decorations.
  """
  def footer(assigns) do
    ~H"""
    <footer class="bg-navy text-gold text-center py-12 border-t-3 border-gold relative">
      <!-- Crucifix at Top -->
      <div class="mx-auto px-8">
        <.medallion type="crucifix" size="medium" />
      </div>

      <div class="mt-8">
        <.ornate_divider variant="white" class="my-12 opacity-20 max-w-sm mx-auto" />

        <p class="font-garamond text-gold-light text-base tracking-wide italic">
          Lumen Viae - Light of the Way
        </p>
        <p class="font-garamond text-gold opacity-70 text-sm mt-2">
          &copy; 2025 All Rights Reserved
        </p>
        <p class="font-cinzel text-gold text-sm tracking-widest uppercase mt-3">
          Ad Majorem Dei Gloriam
        </p>
      </div>
    </footer>
    """
  end
end
