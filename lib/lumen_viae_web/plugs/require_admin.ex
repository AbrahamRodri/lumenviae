defmodule LumenViaeWeb.Plugs.RequireAdmin do
  @moduledoc """
  Requires an admin session for the `/admin` routes, redirecting to the login
  page when there is not one.

  In development the login is skipped entirely: `config/dev.exs` sets
  `:skip_admin_auth`, and this plug marks the session authenticated instead
  of turning the check off, so everything downstream - the LiveView mount
  hook, the logout form, `@is_admin` - behaves exactly as it does in
  production. No other environment sets the flag, and `config/runtime.exs`
  never reads it, so it cannot follow a release out of the door.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      get_session(conn, :admin_authenticated) ->
        conn

      skip_auth?() ->
        put_session(conn, :admin_authenticated, true)

      true ->
        conn
        |> put_flash(:error, "You must be logged in to access this page")
        |> redirect(to: "/admin/login")
        |> halt()
    end
  end

  defp skip_auth?, do: Application.get_env(:lumen_viae, :skip_admin_auth, false)
end
