defmodule LumenViaeWeb.AuthController do
  @moduledoc """
  Where the console's sign-in form lands, and where signing out goes.

  The form on `/admin/login` posts to the password strategy's route, which
  AshAuthentication declares (`auth_routes` in the router) and handles: it
  checks the email and password and calls `success/4` or `failure/3` here.
  A session cookie can only be set on a real HTTP response, which is why
  this is a controller and the login page holds no state of its own.

  Signing out revokes the session's token as well as clearing the cookie,
  so a copy of the old cookie is worthless afterwards.
  """
  use LumenViaeWeb, :controller
  use AshAuthentication.Phoenix.Controller

  @impl AshAuthentication.Phoenix.Controller
  def success(conn, _activity, admin, _token) do
    conn
    |> store_in_session(admin)
    |> put_flash(:info, "Signed in")
    |> redirect(to: "/admin")
  end

  # Says nothing about which half was wrong, so the form cannot be used to
  # find out who has an account.
  @impl AshAuthentication.Phoenix.Controller
  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Incorrect email or password")
    |> redirect(to: "/admin/login")
  end

  @impl AshAuthentication.Phoenix.Controller
  def sign_out(conn, _params) do
    conn
    |> clear_session(:lumen_viae)
    |> put_flash(:info, "Signed out")
    |> redirect(to: "/")
  end
end
