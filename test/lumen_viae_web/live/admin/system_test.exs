defmodule LumenViaeWeb.Live.Admin.SystemTest do
  @moduledoc """
  The System screen reads, and its two acts go through the Ops domain with
  the signed-in admin as actor.
  """
  use LumenViaeWeb.ConnCase, async: true
  use Oban.Testing, repo: LumenViae.Repo

  import Phoenix.LiveViewTest

  alias LumenViae.Office.Jobs.WarmCache

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  test "shows the queues, the schedule, the Office cache and the probes", %{conn: conn} do
    {:ok, view, html} = live(conn, "/admin/system")

    assert html =~ "Queues"
    assert html =~ "maintenance"
    assert html =~ "Office.Jobs.WarmCache"
    assert html =~ "7 0,12 * * *"
    assert html =~ "not run here"
    assert html =~ "Rosary.Completion.LocateScheduler"
    assert html =~ "Office cache"
    assert html =~ "Largest tables"

    # The probes fill in after the page is up.
    assert render_async(view) =~ "switched off: completions are not placed"
  end

  test "links each count to Oban Web, filtered", %{conn: conn} do
    LumenViae.Repo.insert!(%Oban.Job{
      worker: "LumenViae.Test.Worker",
      queue: "geolocation",
      args: %{},
      state: "retryable",
      attempt: 1,
      max_attempts: 3,
      attempted_at: DateTime.utc_now(),
      errors: [%{"attempt" => 1, "at" => "x", "error" => "provider timed out"}]
    })

    {:ok, _view, html} = live(conn, "/admin/system")

    assert html =~ ~s(href="/admin/jobs/jobs?state=retryable&amp;queues=geolocation")
    assert html =~ "provider timed out"
  end

  test "Run now queues the scheduled job", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/system")

    html =
      view
      |> element("button[phx-value-worker='#{inspect(WarmCache)}']", "Run now")
      |> render_click()

    assert html =~ "Queued Office.Jobs.WarmCache as job"
    assert_enqueued(worker: WarmCache)
  end

  test "Empty clears the Office cache", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/system")
    assert view |> element("button", "Empty") |> render_click() =~ "Emptied the Office cache"
  end
end
