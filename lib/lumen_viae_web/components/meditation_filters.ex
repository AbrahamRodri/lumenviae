defmodule LumenViaeWeb.Components.MeditationFilters do
  @moduledoc """
  The three controls - category, author, keyword - that narrow the meditation
  picker on the set new and edit pages.

  Separate from `LumenViaeWeb.Live.Meditations.List.FiltersPanel` because
  that one drives a URL-backed list of every meditation, and this one filters
  a picker held in the LiveView's own assigns. They share the field
  components but not the state model.
  """
  use Phoenix.Component

  import LumenViaeWeb.Components.Admin

  attr :filter_category, :string, default: nil
  attr :filter_author, :string, default: nil
  attr :search_query, :string, default: ""
  attr :available_authors, :list, required: true
  attr :mystery_categories, :list, required: true
  attr :filtered_count, :integer, required: true
  attr :description, :string, default: nil

  def meditation_filters(assigns) do
    ~H"""
    <div>
      <p :if={@description} class="text-[0.8125rem] text-admin-ink-soft mb-3">{@description}</p>

      <.form for={%{}} phx-change="update_filters">
        <div class="grid gap-3 md:grid-cols-3">
          <.filter_select
            name="category"
            label="Category"
            value={@filter_category}
            prompt="All"
            options={@mystery_categories}
          />
          <.filter_select
            name="author"
            label="Author"
            value={@filter_author}
            prompt="All"
            options={Enum.map(@available_authors, &{&1, &1})}
          />
          <.filter_search
            name="query"
            label="Search"
            value={@search_query}
            placeholder="Title, mystery, or keyword"
          />
        </div>
      </.form>

      <p class="text-xs text-admin-ink-soft mt-3">
        <span class="font-semibold text-admin-ink">{@filtered_count}</span> matching meditations
      </p>
    </div>
    """
  end
end
