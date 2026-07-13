defmodule LumenViaeWeb.Components.Admin do
  @moduledoc """
  Shared building blocks for the admin interface: the page shell with the
  admin navigation bar, stat cards, badges, and filter controls.

  Imported globally via `LumenViaeWeb.html_helpers/0`.
  """
  use Phoenix.Component

  @nav_items [
    {"Dashboard", "/admin", "dashboard"},
    {"Meditations", "/admin/meditations", "meditations"},
    {"Meditation Sets", "/admin/meditation-sets", "sets"},
    {"Mysteries", "/admin/mysteries", "mysteries"},
    {"Import CSV", "/admin/meditations/import", "import"}
  ]

  @doc """
  Page shell for every admin screen: admin nav bar, flash messages, page
  header (title, subtitle, actions), and the page body.

  `active` marks the current section in the nav bar: one of "dashboard",
  "meditations", "sets", "mysteries", "import".
  """
  attr :active, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :flash, :map, default: %{}
  attr :max_width, :string, default: "max-w-7xl"
  slot :actions
  slot :inner_block, required: true

  def admin_page(assigns) do
    ~H"""
    <div class="min-h-screen bg-cream">
      <.admin_nav active={@active} />
      <LumenViaeWeb.Layouts.flash_group flash={@flash} />
      <div class={[@max_width, "mx-auto px-8 py-10"]}>
        <div class="flex flex-wrap items-start justify-between gap-4 mb-8">
          <div>
            <h2 class="font-cinzel text-4xl text-navy">{@title}</h2>
            <%= if @subtitle do %>
              <p class="font-crimson text-gray-600 mt-2">{@subtitle}</p>
            <% end %>
          </div>
          <%= if @actions != [] do %>
            <div class="flex flex-wrap items-center gap-3">
              {render_slot(@actions)}
            </div>
          <% end %>
        </div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :active, :string, required: true

  def admin_nav(assigns) do
    assigns = assign(assigns, :items, @nav_items)

    ~H"""
    <nav class="bg-navy border-b-2 border-gold">
      <div class="max-w-7xl mx-auto px-8">
        <div class="flex flex-wrap items-center justify-between gap-x-6">
          <div class="flex flex-wrap items-center gap-x-6">
            <%= for {label, path, key} <- @items do %>
              <.link
                navigate={path}
                class={[
                  "font-crimson py-3 border-b-2 transition-colors",
                  if(@active == key,
                    do: "text-gold border-gold font-semibold",
                    else: "text-cream border-transparent hover:text-gold"
                  )
                ]}
              >
                {label}
              </.link>
            <% end %>
          </div>
          <div class="flex items-center gap-x-6">
            <.link
              navigate="/"
              class="font-crimson py-3 text-cream border-b-2 border-transparent hover:text-gold transition-colors"
            >
              View Site
            </.link>
            <form action="/admin/session" method="post" class="py-2">
              <input
                type="hidden"
                name="_csrf_token"
                value={Plug.CSRFProtection.get_csrf_token()}
              />
              <input type="hidden" name="_method" value="delete" />
              <button
                type="submit"
                class="bg-gold hover:bg-gold-light text-navy px-4 py-1.5 rounded transition-colors font-crimson font-semibold text-sm"
              >
                Logout
              </button>
            </form>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  A small statistics card. When `navigate` is given the whole card links to
  that path.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :hint, :string, default: nil
  attr :navigate, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <%= if @navigate do %>
      <.link
        navigate={@navigate}
        class="block bg-white border-l-4 border-gold p-5 hover:bg-gray-50 transition-colors"
      >
        <.stat_card_body label={@label} value={@value} hint={@hint} />
      </.link>
    <% else %>
      <div class="bg-white border-l-4 border-gold p-5">
        <.stat_card_body label={@label} value={@value} hint={@hint} />
      </div>
    <% end %>
    """
  end

  defp stat_card_body(assigns) do
    ~H"""
    <h4 class="font-cinzel text-base text-navy mb-1">{@label}</h4>
    <p class="font-crimson text-3xl text-gold leading-tight">{@value}</p>
    <%= if @hint do %>
      <p class="font-crimson text-sm text-gray-500 mt-1">{@hint}</p>
    <% end %>
    """
  end

  @doc """
  Inline badge. Tones: "gold" (outline), "navy", "gray", "amber", "red",
  "green".
  """
  attr :tone, :string, default: "gray"
  attr :title, :string, default: nil
  slot :inner_block, required: true

  def admin_badge(assigns) do
    ~H"""
    <span
      title={@title}
      class={[
        "inline-block px-2 py-0.5 font-crimson text-xs rounded whitespace-nowrap align-middle",
        badge_classes(@tone)
      ]}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp badge_classes("gold"), do: "border border-gold text-navy"
  defp badge_classes("navy"), do: "bg-navy text-gold capitalize"
  defp badge_classes("amber"), do: "bg-amber-100 text-amber-800"
  defp badge_classes("red"), do: "bg-red-100 text-red-800"
  defp badge_classes("green"), do: "bg-green-100 text-green-800"
  defp badge_classes(_gray), do: "bg-gray-200 text-gray-600 uppercase tracking-wide"

  @doc """
  Labeled select for filter forms. `options` is a list of {label, value}
  tuples; when `prompt` is given it renders as the blank "all" option.
  """
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, default: nil
  attr :prompt, :string, default: nil
  attr :options, :list, required: true

  def filter_select(assigns) do
    ~H"""
    <div>
      <label class="font-crimson text-navy font-semibold block mb-1 text-sm">{@label}</label>
      <select
        name={@name}
        class="w-full p-2.5 border border-gray-300 rounded font-crimson text-black bg-white"
      >
        <%= if @prompt do %>
          <option value="" selected={@value in [nil, ""]}>{@prompt}</option>
        <% end %>
        <%= for {label, value} <- @options do %>
          <option value={value} selected={to_string(@value) == to_string(value)}>{label}</option>
        <% end %>
      </select>
    </div>
    """
  end

  @doc """
  Labeled debounced text input for filter forms.
  """
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, default: ""

  def filter_search(assigns) do
    ~H"""
    <div>
      <label class="font-crimson text-navy font-semibold block mb-1 text-sm">{@label}</label>
      <input
        type="text"
        name={@name}
        value={@value}
        placeholder={@placeholder}
        class="w-full p-2.5 border border-gray-300 rounded font-crimson text-black bg-white"
        phx-debounce="400"
      />
    </div>
    """
  end

  @doc """
  Muted empty-state message for lists with no results.
  """
  slot :inner_block, required: true

  def empty_state(assigns) do
    ~H"""
    <div class="border border-dashed border-gray-300 rounded-lg p-8 text-center">
      <p class="font-crimson text-gray-500">{render_slot(@inner_block)}</p>
    </div>
    """
  end
end
