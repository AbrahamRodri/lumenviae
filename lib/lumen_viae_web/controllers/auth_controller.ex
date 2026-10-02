defmodule LumenViaeWeb.AuthController do
  @moduledoc """
  Where the console's sign-in form lands, and where signing out goes.

  The form on `/admin/login` posts to the password strategy's route, which
  AshAuthentication declares (`auth_routes` in the router) and handles: it
  checks the email and password and calls `success/4` or `failure/3` here.
  A session cookie can only be set on a real HTTP response, which is why
  this is a controller and the login page holds no state of its own.

  Signing out revokes the session's token as well as clearing the cookie,
  so a copy of the old cookie is worthless afterwards, and closes the
  admin's open console sockets (see `LumenViaeWeb.AdminSockets`).
  """
  use LumenViaeWeb, :controller
  use AshAuthentication.Phoenix.Controller

  require Logger

  alias AshAuthentication.Errors.AuthenticationFailed
  alias LumenViaeWeb.AdminSockets

  @impl AshAuthentication.Phoenix.Controller
  def success(conn, _activity, admin, _token) do
    conn
    |> store_in_session(admin)
    |> put_session(:live_socket_id, AdminSockets.id(admin))
    |> put_flash(:info, "Signed in")
    |> redirect(to: "/admin")
  end

  # Says nothing about which half was wrong, so the form cannot be used to
  # find out who has an account. A failure that was not about the
  # credentials at all - a missing signing secret, the database - shows the
  # same message, but is logged, so it is not mistaken for a typo.
  @impl AshAuthentication.Phoenix.Controller
  def failure(conn, _activity, reason) do
    case faults(reason) do
      [] ->
        :ok

      faults ->
        Logger.error(
          "Console sign-in failed for a reason other than the credentials: " <>
            Enum.map_join(faults, "; ", &Exception.message/1)
        )
    end

    conn
    |> put_flash(:error, "Incorrect email or password")
    |> redirect(to: "/admin/login")
  end

  # What lies under a sign-in failure other than AuthenticationFailed
  # itself. A wrong email or password is AuthenticationFailed all the way
  # down, with a plain map as its innermost cause, so it yields nothing.
  # The messages never include the password: the strategy's argument is
  # sensitive, and Ash redacts it.
  defp faults(%AuthenticationFailed{caused_by: %{__exception__: true} = cause}), do: faults(cause)
  defp faults(%AuthenticationFailed{}), do: []

  defp faults(%{__exception__: true, errors: errors}) when is_list(errors),
    do: Enum.flat_map(errors, &faults/1)

  defp faults(%{__exception__: true} = error), do: [error]
  defp faults(_reason), do: []

  @impl AshAuthentication.Phoenix.Controller
  def sign_out(conn, _params) do
    if admin = conn.assigns[:current_admin], do: AdminSockets.disconnect(admin)

    conn
    |> clear_session(:lumen_viae)
    |> put_flash(:info, "Signed out")
    |> redirect(to: "/")
  end
end
