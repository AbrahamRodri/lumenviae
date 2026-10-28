defmodule LumenViaeWeb.RequestLogTest do
  @moduledoc """
  One structured line per request; a failing one as an error; the noisy
  checks left out unless they fail; never the query string.
  """
  use LumenViaeWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias LumenViaeWeb.RequestLog

  # The suite logs warnings and up; these tests read the info lines too.
  setup do
    Logger.put_module_level(RequestLog, :info)
    on_exit(fn -> Logger.delete_module_level(RequestLog) end)
  end

  defp finished(path, status, query \\ "") do
    conn = %{
      Plug.Test.conn(:get, path <> query)
      | status: status
    }

    capture_log(fn ->
      RequestLog.handle_event(
        [:phoenix, :endpoint, :stop],
        %{duration: System.convert_time_unit(4, :millisecond, :native)},
        %{conn: conn},
        nil
      )
    end)
  end

  test "a request is one line: method, path, status and duration" do
    log = finished("/api/v2/prayer-book", 200)
    assert log =~ "[info] request method=GET path=/api/v2/prayer-book status=200 duration_ms=4.0"
  end

  test "a 5xx is an error" do
    assert finished("/api/v2/office/days/2026-10-28", 503) =~ "[error] request method=GET"
  end

  test "never logs the query string" do
    refute finished("/api/meditations/1/audio", 200, "?voice=secret") =~ "secret"
  end

  test "leaves out the health and robots checks unless they fail" do
    assert finished("/healthz", 200) == ""
    assert finished("/robots.txt", 200) == ""
    assert finished("/healthz", 503) =~ "status=503"
  end

  test "a request that raises is logged with its exception" do
    log =
      capture_log(fn ->
        RequestLog.handle_event(
          [:phoenix, :router_dispatch, :exception],
          %{},
          %{
            conn: Plug.Test.conn(:get, "/api/v2/consecration"),
            kind: :error,
            reason: %RuntimeError{message: "boom\nmore"}
          },
          nil
        )
      end)

    assert log =~ "request_failed method=GET path=/api/v2/consecration kind=error"
    assert log =~ "reason=RuntimeError: boom"
    refute log =~ "more"
  end
end
