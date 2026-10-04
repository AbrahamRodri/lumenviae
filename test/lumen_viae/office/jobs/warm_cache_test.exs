defmodule LumenViae.Office.Jobs.WarmCacheTest do
  @moduledoc """
  Warming the Office cache against a stubbed engine.

  Not async. The job warms through `:erpc.multicall/5`, which runs
  `Office.warm/1` in a process of its own that the test's private Req.Test
  stub cannot reach, so the stub is made shared. ExUnit runs every async
  module before the synchronous ones, so no other test's stub is displaced.

  The cache is one named table that outlives a test, so each test warms
  dates no other test in the suite uses.
  """
  use ExUnit.Case, async: false
  use Oban.Testing, repo: LumenViae.Repo

  alias LumenViae.Office
  alias LumenViae.Office.DivinumOfficium
  alias LumenViae.Office.Jobs.WarmCache

  @fixtures Path.expand("../../../support/fixtures/divinum_officium", __DIR__)

  setup do
    Req.Test.set_req_test_to_shared()
    on_exit(fn -> Req.Test.set_req_test_to_private() end)
  end

  defp stub_engine do
    hour = File.read!(Path.join(@fixtures, "laudes_2026-08-24.html"))
    kalendar = File.read!(Path.join(@fixtures, "kalendar_2026-08.html"))
    test_pid = self()

    Req.Test.stub(DivinumOfficium, fn conn ->
      send(test_pid, {:asked, conn.request_path})

      if String.ends_with?(conn.request_path, "kalendar.pl"),
        do: Req.Test.html(conn, kalendar),
        else: Req.Test.html(conn, hour)
    end)
  end

  defp stub_engine_down do
    test_pid = self()

    Req.Test.stub(DivinumOfficium, fn conn ->
      send(test_pid, {:asked, conn.request_path})
      Plug.Conn.send_resp(conn, 503, "unavailable")
    end)
  end

  defp asked do
    receive do
      {:asked, _path} -> 1 + asked()
    after
      0 -> 0
    end
  end

  test "dates/2 runs from yesterday to the days ahead" do
    assert WarmCache.dates(~D[2026-03-01], 2) ==
             [~D[2026-02-28], ~D[2026-03-01], ~D[2026-03-02], ~D[2026-03-03]]
  end

  describe "Office.warm/1" do
    test "fetches every hour of each date and its month, once" do
      stub_engine()

      assert Office.warm([~D[2031-05-10]]) == %{warmed: 9, cached: 0, failed: 0, skipped: 0}
      assert asked() == 9

      assert Office.warm([~D[2031-05-10]]) == %{warmed: 0, cached: 9, failed: 0, skipped: 0}
      assert asked() == 0
    end

    test "stops at the first failure, and leaves the rest uncached" do
      stub_engine_down()
      assert Office.warm([~D[2032-06-11]]) == %{warmed: 0, cached: 0, failed: 1, skipped: 8}
      assert asked() == 1

      stub_engine()
      assert Office.warm([~D[2032-06-11]]) == %{warmed: 9, cached: 0, failed: 0, skipped: 0}
    end
  end

  describe "the job" do
    test "warms this machine when it is the only one" do
      stub_engine()

      assert [{node, %{failed: 0, warmed: warmed}}] =
               WarmCache.warm_every_node([~D[2033-07-12]], [node()], 5_000)

      assert node == node()
      assert warmed == 9
    end

    test "succeeds on a single machine, and the cache then holds the days" do
      stub_engine()

      assert :ok = perform_job(WarmCache, %{"days_ahead" => 0})
      assert Office.cache_stats().entries > 0
    end

    test "fails, for Oban to retry later, when the engine cannot be reached" do
      # Today's dates may already be warm from the test before.
      Office.clear_cache()
      stub_engine_down()

      assert {:error, message} = perform_job(WarmCache, %{"days_ahead" => 0})
      assert message =~ "1 failed"
    end

    test "reports a machine that does not answer instead of waiting on it" do
      stub_engine()

      results =
        WarmCache.warm_every_node([~D[2034-08-13]], [node(), :"ghost@nowhere.invalid"], 5_000)

      assert [{_here, %{failed: 0}}, {:"ghost@nowhere.invalid", {:error, _reason}}] = results
    end

    test "waits a quarter of an hour, then half an hour, between attempts" do
      assert WarmCache.backoff(%Oban.Job{attempt: 1}) == 900
      assert WarmCache.backoff(%Oban.Job{attempt: 2}) == 1800
    end
  end
end
