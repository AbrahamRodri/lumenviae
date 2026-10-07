defmodule LumenViaeWeb.Components.Nav do
  @moduledoc """
  Navigation component with mobile menu support.
  """
  use Phoenix.Component
  import LumenViaeWeb.CoreComponents
  alias Phoenix.LiveView.JS

  @doc """
  Renders the site navigation header with mobile menu.
  """
  attr :is_admin, :boolean, default: false

  def header(assigns) do
    ~H"""
    <header class="bg-navy border-b-3 border-gold">
      <div class="relative max-w-7xl mx-auto px-6 py-6 flex items-center justify-between">
        <.link navigate="/" class="flex items-center gap-4 hover:opacity-80 transition-opacity">
          <.medallion_bg type="saint_benedict" size="small" />

          <div>
            <span class="block font-cinzel-decorative text-gold text-2xl md:text-3xl tracking-widest font-bold">
              LUMEN VIAE
            </span>
            <p class="font-garamond text-gold-light text-sm tracking-wide italic">
              Meditations on the Holy Rosary
            </p>
          </div>
        </.link>

        <!-- Desktop Navigation -->
        <div class="hidden md:flex items-center gap-6">
          <.nav_link navigate="/">
            Today's Rosary
          </.nav_link>

          <div class="relative flex items-center">
            <button
              type="button"
              id="mysteries-menu-button"
              phx-click={
                JS.toggle(
                  to: "#mysteries-menu",
                  in:
                    {"ease-out duration-200", "opacity-0 -translate-y-1", "opacity-100 translate-y-0"},
                  out:
                    {"ease-in duration-150", "opacity-100 translate-y-0", "opacity-0 -translate-y-1"}
                )
                |> JS.toggle_attribute({"aria-expanded", "true", "false"})
              }
              class="inline-flex items-center gap-1.5 font-cinzel text-[0.8rem] tracking-[0.18em] uppercase text-gold-light hover:text-gold transition-colors"
              aria-expanded="false"
              aria-controls="mysteries-menu"
            >
              The Mysteries
              <svg
                class="w-3 h-3"
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

            <div
              id="mysteries-menu"
              class="hidden absolute right-0 top-full mt-3 w-72 bg-navy border border-gold/40 rounded-lg shadow-ornate py-2 z-50"
              phx-click-away={
                JS.hide(to: "#mysteries-menu")
                |> JS.set_attribute({"aria-expanded", "false"}, to: "#mysteries-menu-button")
              }
            >
              <.menu_link :for={{path, label} <- mystery_links()} navigate={path}>
                {label}
              </.menu_link>
            </div>
          </div>

          <%= if @is_admin do %>
            <.nav_link navigate="/admin">
              Admin
            </.nav_link>
          <% end %>
        </div>

        <!-- Mobile Menu Button -->
        <button
          type="button"
          id="mobile-menu-button"
          phx-click={
            JS.toggle(
              to: "#mobile-menu",
              in: {"ease-out duration-300", "opacity-0 -translate-y-2", "opacity-100 translate-y-0"},
              out: {"ease-in duration-200", "opacity-100 translate-y-0", "opacity-0 -translate-y-2"}
            )
            |> JS.toggle(to: "#menu-icon-open")
            |> JS.toggle(to: "#menu-icon-close")
            |> JS.toggle_attribute({"aria-expanded", "true", "false"})
          }
          class="md:hidden text-gold-light hover:text-gold transition-colors p-2"
          aria-label="Toggle mobile menu"
          aria-expanded="false"
          aria-controls="mobile-menu"
        >
          <svg
            id="menu-icon-open"
            class="w-6 h-6"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 6h16M4 12h16M4 18h16"
            />
          </svg>
          <svg
            id="menu-icon-close"
            class="w-6 h-6 hidden"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
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

      <!-- Mobile Menu -->
      <div
        id="mobile-menu"
        class="hidden md:hidden bg-navy border-t border-gold/30 overflow-hidden"
      >
        <nav class="px-6 py-4 space-y-3">
          <.nav_link navigate="/" mobile>
            Today's Rosary
          </.nav_link>

          <p class="font-cinzel text-[0.65rem] tracking-[0.3em] uppercase text-gold/60 pt-2">
            The Mysteries
          </p>
          <.nav_link :for={{path, label} <- mystery_links()} navigate={path} mobile>
            {label}
          </.nav_link>

          <%= if @is_admin do %>
            <.nav_link navigate="/admin" mobile>
              Admin
            </.nav_link>
            <form action="/admin/session" method="post" class="py-2">
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
              <input type="hidden" name="_method" value="delete" />
              <button
                type="submit"
                class="font-garamond text-lg text-gold-light hover:text-gold transition-colors w-full text-left"
              >
                Logout
              </button>
            </form>
          <% end %>
        </nav>
      </div>
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

  attr :navigate, :string, required: true
  slot :inner_block, required: true

  defp menu_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      phx-click={
        JS.hide(to: "#mysteries-menu")
        |> JS.set_attribute({"aria-expanded", "false"}, to: "#mysteries-menu-button")
      }
      class="block px-5 py-3 font-garamond text-base text-gold-light hover:text-gold hover:bg-gold/10 transition-colors"
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :navigate, :string, required: true
  attr :mobile, :boolean, default: false
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      phx-click={
        if @mobile do
          JS.hide(
            to: "#mobile-menu",
            transition:
              {"ease-in duration-200", "opacity-100 translate-y-0", "opacity-0 -translate-y-2"}
          )
          |> JS.hide(to: "#menu-icon-close")
          |> JS.show(to: "#menu-icon-open")
          |> JS.set_attribute({"aria-expanded", "false"}, to: "#mobile-menu-button")
        else
          nil
        end
      }
      class={[
        "text-gold-light hover:text-gold transition-colors",
        if(@mobile,
          do: "block font-garamond text-lg py-2",
          else: "font-cinzel text-[0.8rem] tracking-[0.18em] uppercase"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
