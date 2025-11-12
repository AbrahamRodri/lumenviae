defmodule LumenViaeWeb.Components.MeditationFilters do
  @moduledoc """
  Reusable meditation filter controls component.
  """
  use Phoenix.Component

  attr :filter_category, :string, default: nil
  attr :filter_author, :string, default: nil
  attr :search_query, :string, default: ""
  attr :available_authors, :list, required: true
  attr :mystery_categories, :list, required: true
  attr :filtered_count, :integer, required: true
  attr :show_description, :boolean, default: false
  attr :description, :string, default: nil
  attr :inline, :boolean, default: false

  def meditation_filters(assigns) do
    ~H"""
    <div class={if @inline, do: "", else: "bg-white border-l-4 border-gold p-6 mb-8"}>
      <h3 class="font-cinzel text-xl text-navy mb-4">Filters</h3>
      <%= if @show_description do %>
        <p class="font-crimson text-gray-600 mb-6">
          {@description ||
            "Narrow the list of meditations by mystery category, author, or keyword. Use the filters to quickly jump to the meditations you want to review or edit."}
        </p>
      <% end %>

      <.form for={%{}} phx-change="update_filters">
        <div class="grid gap-4 md:grid-cols-3">
          <div>
            <label class="font-crimson text-navy font-semibold block mb-2">
              Mystery Category
            </label>
            <select
              name="category"
              class="w-full p-3 border border-gray-300 rounded font-crimson text-black"
            >
              <option value="" selected={is_nil(@filter_category)}>All Categories</option>
              <%= for {label, value} <- @mystery_categories do %>
                <option value={value} selected={@filter_category == value}>{label}</option>
              <% end %>
            </select>
          </div>

          <div>
            <label class="font-crimson text-navy font-semibold block mb-2">
              Author
            </label>
            <select
              name="author"
              class="w-full p-3 border border-gray-300 rounded font-crimson text-black"
            >
              <option value="" selected={is_nil(@filter_author)}>All Authors</option>
              <%= for author <- @available_authors do %>
                <option value={author} selected={@filter_author == author}>{author}</option>
              <% end %>
            </select>
          </div>

          <div>
            <label class="font-crimson text-navy font-semibold block mb-2">
              Search
            </label>
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search meditations by title, mystery, or keyword"
              class="w-full p-3 border border-gray-300 rounded font-crimson text-black"
              phx-debounce="400"
            />
          </div>
        </div>
      </.form>

      <div class="mt-6 flex items-center justify-between">
        <p class="font-crimson text-navy">
          {@filtered_count} matching meditations
        </p>
        <%= if @filter_category || @filter_author || @search_query != "" do %>
          <span class="font-crimson text-sm text-gray-500">Filters applied</span>
        <% end %>
      </div>
    </div>
    """
  end
end
