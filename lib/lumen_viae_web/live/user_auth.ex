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

  Sign-out and a password reset close open sockets at once
  (`LumenViaeWeb.AdminSockets`), but a token simply reaching its expiry
  closes nothing, so a console tab left open would go on acting past it.
  `:require_admin` therefore also schedules the end of the session: when
  the token's `exp` passes, the page sends the admin to the login page, as
  a fresh request would have.
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
      {:cont, expire_with_token(socket, session)}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be signed in to access this page")
       |> redirect(to: "/admin/login")}
    end
  end

  @doc """
  Milliseconds until `token` expires, `0` if it already has, or `nil` if it
  carries no readable expiry. The claims are only peeked at: the token was
  verified when the admin was loaded from it.
  """
  def ms_until_expiry(token) when is_binary(token) do
    case AshAuthentication.Jwt.peek(token) do
      {:ok, %{"exp" => exp}} when is_integer(exp) ->
        max(exp * 1000 - System.system_time(:millisecond), 0)

      _unreadable ->
        nil
    end
  end

  def ms_until_expiry(_no_token), do: nil

  defp expire_with_token(socket, session) do
    with true <- connected?(socket),
         ms when is_integer(ms) <- ms_until_expiry(session["admin_token"]) do
      Process.send_after(self(), :admin_session_expired, ms)
      attach_hook(socket, :admin_session_expiry, :handle_info, &handle_expiry/2)
    else
      _not_scheduled -> socket
    end
  end

  defp handle_expiry(:admin_session_expired, socket) do
    {:halt,
     socket
     |> put_flash(:error, "Your session has expired. Please sign in again.")
     |> redirect(to: "/admin/login")}
  end

  defp handle_expiry(_message, socket), do: {:cont, socket}

  defp load_admin(params, session, socket) do
    {:cont, socket} = LiveSession.on_mount(:default, params, session, socket)
    admin = socket.assigns[:current_admin]

    socket
    |> assign(:current_admin, admin)
    |> assign(:is_admin, not is_nil(admin))
  end
end
