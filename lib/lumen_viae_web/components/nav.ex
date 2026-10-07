defmodule LumenViaeWeb.Components.Nav do
  @moduledoc """
  The public site's header: the wordmark, Today's Rosary, and a Mysteries
  menu of the five categories and the Scripture page.

  The header lives in the root layout, outside every LiveView, so its menus
  are driven by `assets/js/site_nav.js` rather than by LiveView JS commands:
  the script opens and closes them, keeps `aria-expanded` true to what is on
  screen, closes them on Escape (returning focus to the button), on a click
  outside and on navigation, and moves `aria-current="page"` as live
  navigation changes the page. The server marks the first page it renders.

  A page that wants the whole screen (the prayer page) hides the header and
  footer by carrying `data-layout="focused"`; see the site shell section of
  `assets/css/app.css`.
  """
  use Phoenix.Component
  import LumenViaeWeb.CoreComponents

  @doc """
  Renders the site navigation header with its mobile menu.
  """
  attr :is_admin, :boolean, default: false
  attr :current_path, :string, default: nil, doc: "the request path, to mark the current page"

  def header(assigns) do
    ~H"""
    <header id="site-header" class="site-header bg-navy border-b-2 md:border-b-3 border-gold">
      <div class="relative max-w-7xl mx-auto px-4 sm:px-6 py-2.5 md:py-6 flex items-center justify-between gap-4">
        <.link
          navigate="/"
          class="flex items-center gap-3 md:gap-4 min-h-11 rounded-sm hover:opacity-90 transition-opacity"
          aria-label="Lumen Viae, home"
        >
          <.medallion_bg type="saint_benedict" size="small" class="shrink-0 scale-90 md:scale-100" />

          <span class="block">
            <span class="block font-cinzel-decorative text-gold text-xl sm:text-2xl md:text-3xl tracking-widest font-bold leading-tight">
              LUMEN VIAE
            </span>
            <span class="hidden sm:block font-garamond text-gold-light text-sm tracking-wide italic">
              Meditations on the Holy Rosary
            </span>
          </span>
        </.link>

        <nav class="hidden md:flex items-center gap-2" aria-label="Main">
          <.nav_link navigate="/" current_path={@current_path}>
            Today's Rosary
          </.nav_link>

          <div class="relative" data-menu>
            <button
              type="button"
              id="mysteries-menu-button"
              data-menu-toggle
              class="group inline-flex items-center gap-1.5 min-h-11 px-3 rounded-sm font-cinzel text-[0.8rem] tracking-[0.18em] uppercase text-gold-light hover:text-cream transition-colors aria-expanded:text-cream"
              aria-expanded="false"
              aria-controls="mysteries-menu"
            >
              The Mysteries
              <svg
                class="w-3 h-3 transition-transform group-aria-expanded:rotate-180"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </button>

            <ul
              id="mysteries-menu"
              class="hidden absolute right-0 top-full mt-3 w-72 bg-navy border border-gold/40 rounded-lg shadow-ornate py-2 z-50"
            >
              <li :for={{path, label} <- mystery_links()}>
                <.link
                  navigate={path}
                  data-nav-link
                  aria-current={current(path, @current_path)}
                  class="flex items-center min-h-11 px-5 py-2 font-garamond text-base text-gold-light hover:text-cream hover:bg-gold/10 aria-[current=page]:text-cream aria-[current=page]:bg-gold/15 transition-colors"
                >
                  {label}
                </.link>
              </li>
            </ul>
          </div>

          <.nav_link :if={@is_admin} navigate="/admin" current_path={@current_path}>
            Admin
          </.nav_link>
        </nav>

        <button
          type="button"
          id="mobile-menu-button"
          data-menu-toggle
          class="group md:hidden inline-flex items-center justify-center size-11 -mr-2 rounded-sm text-gold-light hover:text-cream transition-colors"
          aria-label="Menu"
          aria-expanded="false"
          aria-controls="mobile-menu"
        >
          <svg
            class="w-6 h-6 group-aria-expanded:hidden"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 6h16M4 12h16M4 18h16"
            />
          </svg>
          <svg
            class="w-6 h-6 hidden group-aria-expanded:block"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>

      <nav
        id="mobile-menu"
        class="hidden md:hidden bg-navy border-t border-gold/30 max-h-[calc(100dvh-4rem)] overflow-y-auto overscroll-contain"
        aria-label="Main"
      >
        <ul class="px-4 sm:px-6 py-3">
          <li>
            <.nav_link navigate="/" current_path={@current_path} mobile>
              Today's Rosary
            </.nav_link>
          </li>
          <li class="pt-3">
            <p
              id="mobile-mysteries-heading"
              class="font-cinzel text-[0.7rem] tracking-[0.3em] uppercase text-gold-light/90 pb-1"
            >
              The Mysteries
            </p>
            <ul aria-labelledby="mobile-mysteries-heading">
              <li :for={{path, label} <- mystery_links()}>
                <.nav_link navigate={path} current_path={@current_path} mobile>
                  {label}
                </.nav_link>
              </li>
            </ul>
          </li>

          <li :if={@is_admin} class="pt-3 mt-3 border-t border-gold/20">
            <.nav_link navigate="/admin" current_path={@current_path} mobile>
              Admin
            </.nav_link>
            <form action="/admin/session" method="post">
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
              <input type="hidden" name="_method" value="delete" />
              <button
                type="submit"
                class="flex items-center w-full min-h-11 font-garamond text-lg text-gold-light hover:text-cream transition-colors text-left"
              >
                Logout
              </button>
            </form>
          </li>
        </ul>
      </nav>
    </header>
    """
  end

  defp mystery_links do
    [
      {"/mysteries/joyful", "The Joyful Mysteries"},
      {"/mysteries/sorrowful", "The Sorrowful Mysteries"},
      {"/mysteries/glorious", "The Glorious Mysteries"},
      {"/mysteries/luminous", "The Luminous Mysteries"},
      {"/mysteries/seven_sorrows", "The Seven Sorrows of Mary"},
      {"/mysteries", "The Mysteries in Scripture"}
    ]
  end

  # The prayer page belongs to its category, so a set's prayer page marks
  # nothing: its path is not one the header links to.
  defp current(path, path), do: "page"
  defp current(_path, _current_path), do: nil

  attr :navigate, :string, required: true
  attr :current_path, :string, default: nil
  attr :mobile, :boolean, default: false
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      data-nav-link
      aria-current={current(@navigate, @current_path)}
      class={[
        "text-gold-light hover:text-cream aria-[current=page]:text-cream transition-colors",
        if(@mobile,
          do:
            "flex items-center min-h-11 font-garamond text-lg aria-[current=page]:underline decoration-gold underline-offset-4",
          else:
            "inline-flex items-center min-h-11 px-3 rounded-sm font-cinzel text-[0.8rem] tracking-[0.18em] uppercase border-b-2 border-transparent aria-[current=page]:border-gold"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
