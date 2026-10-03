defmodule LumenViaeWeb.ObanResolver do
  @moduledoc """
  How Oban Web, at `/admin/jobs`, behaves for whoever opens it.

  Access is the router's business, not this module's: the dashboard is
  mounted behind the console's own guard (`LumenViaeWeb.Plugs.RequireAdmin`
  and the `:require_admin` hook), so anybody who reaches it is an admin and
  may do everything it offers.

  What this changes is the refresh. The dashboard re-reads the jobs table
  every second by default for as long as it is open, which is a query a
  second against the 256MB production database for a page that is mostly
  left open in a tab. Every five seconds is still live enough to watch a
  queue drain. The dashboard's own control can still change it.
  """
  @behaviour Oban.Web.Resolver

  # Who is looking, so the dashboard knows who acted: the signed-in
  # admin's id and email, and nothing else. Oban Web keeps this in its
  # LiveView session, which is signed into the page but not encrypted, so
  # the whole Admin record (hashed_password and all) must not go there.
  @impl true
  def resolve_user(conn) do
    case conn.assigns[:current_admin] do
      %{id: id, email: email} -> %{id: id, email: to_string(email)}
      _nobody -> nil
    end
  end

  @impl true
  def resolve_access(_admin), do: :all

  @impl true
  def resolve_refresh(_admin), do: 5
end
