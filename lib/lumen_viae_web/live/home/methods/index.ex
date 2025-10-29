defmodule LumenViaeWeb.Live.Home.Methods.Index do
  @moduledoc """
  LiveView for displaying St. Louis de Montfort's methods of praying the Rosary
  """
  use LumenViaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Methods of Praying the Rosary")}
  end
end
