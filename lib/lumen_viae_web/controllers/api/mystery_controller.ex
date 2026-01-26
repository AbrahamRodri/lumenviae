defmodule LumenViaeWeb.API.MysteryController do
  use LumenViaeWeb, :controller
  alias LumenViae.Rosary

  action_fallback LumenViaeWeb.API.FallbackController

  @doc """
  Lists all mysteries, optionally filtered by category.
  """
  def index(conn, %{"category" => category}) do
    mysteries = Rosary.list_mysteries_by_category(category)
    render(conn, :index, mysteries: mysteries)
  end

  def index(conn, _params) do
    mysteries = Rosary.list_mysteries()
    render(conn, :index, mysteries: mysteries)
  end
end
