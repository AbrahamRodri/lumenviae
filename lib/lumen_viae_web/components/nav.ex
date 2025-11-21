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
            <h1 class="font-cinzel-decorative text-gold text-2xl md:text-3xl tracking-widest font-bold">
              LUMEN VIAE
            </h1>
            <p class="font-garamond text-gold-light text-sm tracking-wide italic">
              Meditations on the Holy Rosary
            </p>
          </div>
        </.link>
        
    <!-- Desktop Navigation -->
        <div class="hidden md:flex items-center gap-6">
          <.nav_link navigate="/dashboard">
            Dashboard
          </.nav_link>
          <.nav_link navigate="/mysteries">
            Scripture of the Rosary
          </.nav_link>
          <.nav_link navigate="/rosary-methods">
            Rosary Methods
          </.nav_link>
          <.nav_link navigate="/feedback">
            Feedback
          </.nav_link>
          <%= if @is_admin do %>
            <.nav_link navigate="/admin">
              Admin
            </.nav_link>
          <% end %>
        </div>
        
    <!-- Mobile Menu Button -->
        <button
          type="button"
          phx-click={
            JS.toggle(
              to: "#mobile-menu",
              in: {"ease-out duration-300", "opacity-0 -translate-y-2", "opacity-100 translate-y-0"},
              out: {"ease-in duration-200", "opacity-100 translate-y-0", "opacity-0 -translate-y-2"}
            )
            |> JS.toggle(to: "#menu-icon-open")
            |> JS.toggle(to: "#menu-icon-close")
          }
          class="md:hidden text-gold-light hover:text-gold transition-colors p-2"
          aria-label="Toggle mobile menu"
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
          <.nav_link navigate="/dashboard" mobile>
            Dashboard
          </.nav_link>
          <.nav_link navigate="/mysteries" mobile>
            Scripture of the Rosary
          </.nav_link>
          <.nav_link navigate="/rosary-methods" mobile>
            Rosary Methods
          </.nav_link>
          <.nav_link navigate="/feedback" mobile>
            Feedback
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
                class="font-work-sans text-base text-gold-light hover:text-gold transition-colors w-full text-left"
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
        else
          nil
        end
      }
      class={[
        "font-work-sans text-gold-light hover:text-gold transition-colors",
        if(@mobile, do: "block text-base py-2", else: "text-sm")
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
