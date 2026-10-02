defmodule LumenViaeWeb.UserAuth do
  @moduledoc """
  LiveView lifecycle hooks for the admin session.

  `:default` runs on every LiveView. It loads the signed-in admin, if any,
  into `current_admin` - the actor the page passes to the domain - and sets
  `@is_admin` for the pages that show the console's links. A visitor's
  session has no token, so this costs them nothing.

  `:require_admin` guards the console, and it is the guard that actually
  holds. `LumenViaeWeb.Plugs.RequireAdmin` runs only on an HTTP request,
  and a LiveView can be reached without one: live navigation mounts the
  next page over the open websocket and runs no plug at all. So the router
  puts the console in its own `live_session` with this hook, which means
  navigation into it from a public page is forced through a full HTTP
  request (and the plug), and a socket that arrives without a signed-in
  admin anyway is refused here. The token is checked afresh on every
  mount, so a socket opened before sign-out cannot mount another console
  page after it.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  alias AshAuthentication.Phoenix.LiveSession

  def on_mount(:default, params, session, socket) do
    {:cont, load_admin(params, session, socket)}
  end

  def on_mount(:require_admin, params, session, socket) do
    socket = load_admin(params, session, socket)

    if socket.assigns.current_admin do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be signed in to access this page")
       |> redirect(to: "/admin/login")}
    end
  end

  defp load_admin(params, session, socket) do
    {:cont, socket} = LiveSession.on_mount(:default, params, session, socket)
    admin = socket.assigns[:current_admin]

    socket
    |> assign(:current_admin, admin)
    |> assign(:is_admin, not is_nil(admin))
  end
end
