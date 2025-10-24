defmodule LumenViaeWeb.Live.Mysteries.Index do
  @moduledoc """
  LiveView for displaying all 20 mysteries of the Rosary with their Biblical references
  """
  use LumenViaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "The Mysteries of the Rosary")}
  end
end
