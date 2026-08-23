defmodule LumenViaeWeb.Live.Meditations.List.FiltersPanel do
  @moduledoc """
  Filter controls for the admin meditations list. Stateless; events are
  handled by the parent LiveView (`update_filters`, `clear_filters`).
  """
  use LumenViaeWeb, :html

  alias LumenViae.Rosary.Categories

  attr :filters, :map, required: true
  attr :mystery_categories, :list, required: true
  attr :mysteries, :list, required: true
  attr :available_authors, :list, required: true
  attr :meditation_sets, :list, required: true
  attr :shown_count, :integer, required: true
  attr :total_count, :integer, required: true
  attr :filtered, :boolean, required: true

  def filters_panel(assigns) do
    ~H"""
    <.panel class="mb-5">
      <.form for={%{}} phx-change="update_filters">
        <div class="grid gap-3 grid-cols-2 md:grid-cols-4 xl:grid-cols-8">
          <.filter_search
            name="q"
            label="Search"
            value={@filters.query}
            placeholder="Title, author, source, or text"
          />

          <.filter_select
            name="category"
            label="Category"
            value={@filters.category}
            prompt="All"
            options={@mystery_categories}
          />

          <.filter_select
            name="mystery"
            label="Mystery"
            value={@filters.mystery}
            prompt="All"
            options={mystery_options(@mysteries)}
          />

          <.filter_select
            name="author"
            label="Author"
            value={@filters.author}
            prompt="All"
            options={Enum.map(@available_authors, &{&1, &1})}
          />

          <.filter_select
            name="audio"
            label="Narration"
            value={@filters.audio}
            prompt="Any"
            options={[{"Has audio", "with"}, {"Missing audio", "without"}]}
          />

          <.filter_select
            name="status"
            label="Status"
            value={@filters.status}
            options={[
              {"Active only", "active"},
              {"Archived only", "archived"},
              {"Active and archived", "all"}
            ]}
          />

          <.filter_select
            name="set"
            label="Set"
            value={set_filter_value(@filters.set)}
            prompt="Any"
            options={set_options(@meditation_sets)}
          />

          <.filter_select
            name="sort"
            label="Sort"
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

      <.filter_summary
        shown={@shown_count}
        total={@total_count}
        noun="meditations"
        filtered={@filtered}
      />
    </.panel>
    """
  end

  defp mystery_options(mysteries) do
    Enum.map(mysteries, fn mystery ->
      {"#{mystery.name} (#{Categories.label(mystery.category)})", mystery.id}
    end)
  end

  defp set_options(meditation_sets) do
    [{"Not in any set", "none"}] ++
      Enum.map(meditation_sets, fn set ->
        {"#{set.name} (#{Categories.label(set.category)})", set.id}
      end)
  end

  defp set_filter_value(:none), do: "none"
  defp set_filter_value(value), do: value
end
