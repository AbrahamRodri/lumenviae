defmodule LumenViaeWeb.UserAuth do
  @moduledoc """
  LiveView lifecycle hooks for the admin session.

  `:default` runs on every LiveView and only records whether the visitor
  is signed in, for pages that show the console's links.

  `:require_admin` guards the console, and it is the guard that actually
  holds. `LumenViaeWeb.Plugs.RequireAdmin` runs only on an HTTP request,
  and a LiveView can be reached without one: live navigation mounts the
  next page over the open websocket and runs no plug at all. So the router
  puts the console in its own `live_session` with this hook, which means
  navigation into it from a public page is forced through a full HTTP
  request (and the plug), and a socket that arrives without an admin
  session anyway is refused here.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, session, socket) do
    is_admin = Map.get(session, "admin_authenticated", false)
    {:cont, assign(socket, :is_admin, is_admin)}
  end

  def on_mount(:require_admin, _params, session, socket) do
    if Map.get(session, "admin_authenticated", false) do
      {:cont, assign(socket, :is_admin, true)}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be logged in to access this page")
       |> redirect(to: "/admin/login")}
    end
  end
end
