defmodule LumenViaeWeb.Live.Admin.SystemTest do
  @moduledoc """
  The System screen reads, and its two acts go through the Ops domain with
  the signed-in admin as actor.

  The screen probes the third parties after it mounts. In the suite S3 and
  the Office engine answer at once from config (`:ops_probe_answers`), and
  every `render_async/2` waits up to ten seconds rather than LiveViewTest's
  default 100 ms, which a slow CI runner can miss.
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
    assert render_async(view, 10_000) =~ "switched off: completions are not placed"
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

  # The button only exists for crontab workers, but the event carries the
  # worker's name from the browser. A forged one is refused by the Ops
  # domain, and the screen says so rather than queueing it.
  test "a forged Run now for a worker off the crontab queues nothing", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/system")
    worker = "LumenViae.Curation.Jobs.NarrateMeditation"

    html = render_click(view, "run_job", %{"worker" => worker})

    assert html =~ "Could not queue Curation.Jobs.NarrateMeditation"
    assert html =~ "is not in the crontab"
    refute_enqueued(worker: worker)
  end

  test "Run now shows only once for a worker the crontab names twice", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/system")

    buttons =
      view
      |> render()
      |> Floki.parse_document!()
      |> Floki.find("button[phx-click=run_job]")
      |> Enum.flat_map(&Floki.attribute(&1, "phx-value-worker"))

    assert buttons != []
    assert buttons == Enum.uniq(buttons)
  end

  test "Refresh reloads the screen and checks the third parties again", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/system")
    render_async(view, 10_000)

    LumenViae.Repo.insert!(%Oban.Job{
      worker: "LumenViae.Test.Worker",
      queue: "geolocation",
      args: %{},
      state: "discarded",
      attempt: 3,
      max_attempts: 3,
      attempted_at: DateTime.utc_now(),
      errors: [%{"attempt" => 3, "at" => "x", "error" => "gave up after three tries"}]
    })

    refute render(view) =~ "gave up after three tries"

    html = view |> element("button[phx-click=refresh]") |> render_click()

    assert html =~ "Refreshed."
    assert html =~ "gave up after three tries"
    assert render_async(view, 10_000) =~ "switched off: completions are not placed"
  end
end
