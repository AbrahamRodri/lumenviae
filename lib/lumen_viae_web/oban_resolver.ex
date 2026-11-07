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

  # Everything but Retry. A recording cancelled as "may be billed" left
  # nothing at its S3 key, so running it again pays the voice service twice,
  # and the dashboard cannot limit Retry to some queues. Other jobs are
  # retried with `mix lumen_viae.jobs retry` or `Release.retry_jobs/1`,
  # which refuse the paid queue.
  @access [
    cancel_jobs: true,
    cancel_workflows: true,
    delete_crons: true,
    delete_jobs: true,
    delete_pruners: true,
    insert_crons: true,
    insert_jobs: true,
    insert_pruners: true,
    pause_crons: true,
    pause_pruners: true,
    pause_queues: true,
    retry_jobs: false,
    retry_workflows: false,
    scale_queues: true,
    stop_queues: true,
    update_crons: true,
    update_jobs: true,
    update_pruners: true
  ]

  @impl true
  def resolve_access(_admin), do: @access

  @impl true
  def resolve_refresh(_admin), do: 5
end
