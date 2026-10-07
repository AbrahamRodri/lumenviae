defmodule LumenViaeWeb.Components.Footer do
  @moduledoc """
  The public site's footer: the Stella Maris mark, the site's links and the
  colophon.
  """
  use Phoenix.Component
  import LumenViaeWeb.CoreComponents

  @categories [
    {"/mysteries/joyful", "Joyful"},
    {"/mysteries/sorrowful", "Sorrowful"},
    {"/mysteries/glorious", "Glorious"},
    {"/mysteries/luminous", "Luminous"},
    {"/mysteries/seven_sorrows", "Seven Sorrows"}
  ]

  @doc """
  Renders the site footer.
  """
  def footer(assigns) do
    assigns = assign(assigns, :categories, @categories)

    ~H"""
    <footer
      id="site-footer"
      class="site-footer bg-night-deep text-center border-t border-night-border"
    >
      <div class="max-w-3xl mx-auto px-4 sm:px-8 pt-12 pb-10 md:pt-14">
        <.logo size={:lg} class="text-gilt mx-auto" />

        <nav class="mt-8" aria-label="Footer">
          <ul class="flex flex-wrap justify-center gap-x-2 sm:gap-x-4">
            <li><.footer_link navigate="/">Today's Rosary</.footer_link></li>
            <li><.footer_link navigate="/mysteries">Mysteries in Scripture</.footer_link></li>
            <li><.footer_link navigate="/app">The App</.footer_link></li>
          </ul>

          <p
            id="footer-pray-heading"
            class="mt-5 kicker"
          >
            Pray the Mysteries
          </p>
          <ul
            class="mt-1 flex flex-wrap justify-center gap-x-2 sm:gap-x-4"
            aria-labelledby="footer-pray-heading"
          >
            <li :for={{path, label} <- @categories}>
              <.footer_link navigate={path}>{label}</.footer_link>
            </li>
          </ul>
        </nav>

        <.sacred_divider class="my-8 max-w-xs mx-auto" />

        <p class="font-garamond text-ink-light text-xl italic">
          Lumen Viae - Light of the Way
        </p>
        <p class="kicker mt-3">
          Ad Majorem Dei Gloriam
        </p>
        <p class="font-garamond text-ink-muted text-base mt-6">
          &copy; {Date.utc_today().year} Lumen Viae. All rights reserved.
          <span aria-hidden="true" class="mx-1.5">&middot;</span>
          <.link
            navigate="/privacy-policy"
            class="inline-flex items-center min-h-11 text-sky underline underline-offset-4 hover:text-ink-light transition-colors"
          >
            Privacy Policy
          </.link>
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
