defmodule LumenViaeWeb.Live.Meditations.List.FiltersPanel do
  @moduledoc """
  Filter controls for the admin meditations list. Stateless; events are
  handled by the parent LiveView (`update_filters`, `clear_filters`).
  """
  use LumenViaeWeb, :html

  alias LumenViae.Constants

  attr :filters, :map, required: true
  attr :mystery_categories, :list, required: true
  attr :mysteries, :list, required: true
  attr :available_authors, :list, required: true
  attr :meditation_sets, :list, required: true
  attr :shown_count, :integer, required: true
  attr :total_count, :integer, required: true

  def filters_panel(assigns) do
    ~H"""
    <div class="bg-white border-l-4 border-gold p-6 mb-8">
      <h3 class="font-cinzel text-xl text-navy mb-4">Filters</h3>

      <.form for={%{}} phx-change="update_filters">
        <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <.filter_search
            name="q"
            label="Search"
            value={@filters.query}
            placeholder="Title, author, source, mystery, or text"
          />

          <.filter_select
            name="category"
            label="Mystery Category"
            value={@filters.category}
            prompt="All Categories"
            options={@mystery_categories}
          />

          <.filter_select
            name="mystery"
            label="Mystery"
            value={@filters.mystery}
            prompt="All Mysteries"
            options={mystery_options(@mysteries)}
          />

          <.filter_select
            name="author"
            label="Author"
            value={@filters.author}
            prompt="All Authors"
            options={Enum.map(@available_authors, &{&1, &1})}
          />

          <.filter_select
            name="audio"
            label="Audio"
            value={@filters.audio}
            prompt="With or Without Audio"
            options={[{"Has audio", "with"}, {"Missing audio", "without"}]}
          />

          <.filter_select
            name="status"
            label="Status"
            value={@filters.status}
            prompt="Active and Archived"
            options={[{"Active only", "active"}, {"Archived only", "archived"}]}
          />

          <.filter_select
            name="set"
            label="Set Membership"
            value={set_filter_value(@filters.set)}
            prompt="Any Set Membership"
            options={set_options(@meditation_sets)}
          />

          <.filter_select
            name="sort"
            label="Sort By"
            value={@filters.sort}
            options={[
              {"Mystery order", "mystery"},
              {"Newest first", "newest"},
              {"Oldest first", "oldest"},
              {"Recently updated", "updated"},
              {"Author (A-Z)", "author"},
              {"Title (A-Z)", "title"}
            ]}
          />
        </div>
      </.form>

      <div class="mt-4 flex flex-wrap items-center justify-between gap-3">
        <p class="font-crimson text-navy">
          Showing {@shown_count} of {@total_count} meditations
        </p>
        <%= if filters_applied?(@filters) do %>
          <button
            type="button"
            phx-click="clear_filters"
            class="font-crimson text-sm text-navy border border-navy rounded px-3 py-1 hover:bg-navy hover:text-white transition-colors"
          >
            Clear all filters
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp filters_applied?(filters) do
    filters.query != "" or filters.category != nil or filters.mystery != nil or
      filters.author != nil or filters.audio != nil or filters.status != nil or
      filters.set != nil or filters.sort != "mystery"
  end

  defp mystery_options(mysteries) do
    Enum.map(mysteries, fn mystery ->
      {"#{mystery.name} (#{Constants.mystery_category_label(mystery.category)})", mystery.id}
    end)
  end

  defp set_options(meditation_sets) do
    [{"Not in any set", "none"}] ++
      Enum.map(meditation_sets, fn set ->
        {"#{set.name} (#{Constants.mystery_category_label(set.category)})", set.id}
      end)
  end

  defp set_filter_value(:none), do: "none"
  defp set_filter_value(value), do: value
end
