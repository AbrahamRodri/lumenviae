defmodule LumenViaeWeb.Plugs.RequireAdmin do
  @moduledoc """
  Plug to require admin authentication for protected routes.
  Redirects to login page if not authenticated.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :admin_authenticated) do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: "/admin/login")
      |> halt()
    end
  end
end
