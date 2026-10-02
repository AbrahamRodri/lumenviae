defmodule LumenViaeWeb.Live.Admin.Login do
  @moduledoc """
  The console's front door: an email and a password.

  The form posts to the password strategy's route (see
  `LumenViaeWeb.AuthController`) rather than to this LiveView, because the
  session cookie has to be set on a real HTTP response; a LiveView cannot
  write one. So this screen holds no state at all - the outcome comes back
  as a flash on the redirect. An admin who is already signed in is sent
  straight on to the console.

  In development the login is skipped and `/admin` opens straight away as
  the seeded dev admin (see `LumenViaeWeb.Plugs.RequireAdmin`).
  """
  use LumenViaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_admin do
      {:ok, redirect(socket, to: "/admin")}
    else
      {:ok, assign(socket, :page_title, "Sign in")}
    end
  end
end
