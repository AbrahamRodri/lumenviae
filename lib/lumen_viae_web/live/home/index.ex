defmodule LumenViaeWeb.Live.Home.Index do
  @moduledoc """
  Home page - displays welcome message and mystery categories
  """
  use LumenViaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
