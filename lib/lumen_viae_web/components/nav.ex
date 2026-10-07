defmodule LumenViaeWeb.Components.Nav do
  @moduledoc """
  The public site's header: the Stella Maris mark and the wordmark, Today's
  Rosary, and a Mysteries menu of the five categories and the Scripture
  page.

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
    <header id="site-header" class="site-header bg-night-deep border-b border-night-border">
      <div class="relative max-w-7xl mx-auto px-4 sm:px-6 py-2 md:py-4 flex items-center justify-between gap-3">
        <.link
          navigate="/"
          class="flex min-w-0 items-center gap-2.5 md:gap-3 min-h-11 rounded-sm hover:opacity-90 transition-opacity"
          aria-label="Lumen Viae, home"
        >
          <.logo />

          <span class="block min-w-0">
            <span class="block font-display font-semibold text-ink-light text-2xl md:text-[1.75rem] leading-tight">
              Lumen Viae
            </span>
            <span class="hidden sm:block font-garamond text-ink-muted text-sm italic leading-snug">
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
              class="group inline-flex items-center gap-1.5 min-h-11 px-3 rounded-sm font-garamond text-lg text-ink-muted hover:text-ink-light transition-colors aria-expanded:text-ink-light"
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
              class="hidden absolute right-0 top-full mt-3 w-72 bg-night-raised border border-night-line rounded-lg shadow-night py-2 z-50"
            >
              <li :for={{path, label} <- mystery_links()}>
                <.link
                  navigate={path}
                  data-nav-link
                  aria-current={current(path, @current_path)}
                  class="flex items-center min-h-11 px-5 py-2 font-garamond text-lg text-ink-light hover:bg-night aria-[current=page]:text-gilt aria-[current=page]:bg-night transition-colors"
                >
                  {label}
                </.link>
              </li>
            </ul>
          </div>

          <.nav_link navigate="/app" current_path={@current_path}>
            The App
          </.nav_link>

          <.nav_link :if={@is_admin} navigate="/admin" current_path={@current_path}>
            Admin
          </.nav_link>
        </nav>

        <button
          type="button"
          id="mobile-menu-button"
          data-menu-toggle
          class="group md:hidden inline-flex shrink-0 items-center justify-center size-11 -mr-2 rounded-sm text-ink-light hover:text-gilt transition-colors"
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
        class="hidden md:hidden bg-night-deep border-t border-night-border max-h-[calc(100dvh-4rem)] overflow-y-auto overscroll-contain"
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
              class="kicker pb-1"
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

          <li class="pt-3 mt-3 border-t border-night-border">
            <.nav_link navigate="/app" current_path={@current_path} mobile>
              The App
            </.nav_link>
          </li>

          <li :if={@is_admin} class="pt-3 mt-3 border-t border-night-border">
            <.nav_link navigate="/admin" current_path={@current_path} mobile>
              Admin
            </.nav_link>
            <form action="/admin/session" method="post">
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
              <input type="hidden" name="_method" value="delete" />
              <button
                type="submit"
                class="flex items-center w-full min-h-11 font-garamond text-lg text-ink-light hover:text-gilt transition-colors text-left"
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
        "transition-colors",
        if(@mobile,
          do:
            "flex items-center min-h-11 font-garamond text-lg text-ink-light hover:text-gilt aria-[current=page]:text-gilt aria-[current=page]:underline decoration-gilt underline-offset-4",
          else:
            "inline-flex items-center min-h-11 px-3 rounded-sm font-garamond text-lg text-ink-muted hover:text-ink-light aria-[current=page]:text-ink-light border-b-2 border-transparent aria-[current=page]:border-gilt"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
