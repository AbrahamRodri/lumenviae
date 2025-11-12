defmodule LumenViaeWeb.Live.Meditations.Helpers do
  @moduledoc """
  Helper functions for meditation-related LiveViews.
  """

  alias LumenViae.Meditations.Filtering

  @doc """
  Filters meditations based on assigns containing filter_category, filter_author, and search_query.
  """
  def filtered_meditations(assigns) do
    Filtering.filter_meditations(assigns.meditations, %{
      category: assigns.filter_category,
      author: assigns.filter_author,
      query: assigns.search_query
    })
  end
end
