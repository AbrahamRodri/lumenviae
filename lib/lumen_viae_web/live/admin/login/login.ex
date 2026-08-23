defmodule LumenViaeWeb.Live.Admin.Login do
  @moduledoc """
  The console's front door.

  The form posts to `LumenViaeWeb.AdminSessionController` rather than to this
  LiveView, because the session cookie has to be set on a real HTTP response;
  a LiveView cannot write one. So this screen holds no state at all - the
  outcome comes back as a flash on the redirect.

  In development the login is skipped entirely and `/admin` opens straight
  away (see `LumenViaeWeb.Plugs.RequireAdmin`).
  """
  use LumenViaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Sign in")}
  end
end
