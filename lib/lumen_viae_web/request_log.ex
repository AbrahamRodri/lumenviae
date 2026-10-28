defmodule LumenViaeWeb.RequestLog do
  @moduledoc """
  One log line per request, in place of Phoenix's two ("GET /x", then
  "Sent 200 in 5ms"), so a filter on the log finds a request whole:

      request method=GET path=/api/v2/prayer-book status=200 duration_ms=4.2

  The path never carries the query string, which can hold a signed link or
  a search. A 5xx is logged as an error, so `fly logs` filtered on
  `[error]` shows it; the request id (`Plug.RequestId`) rides in the line's
  metadata, as on every other line of that request. A request that raises
  is logged as `request_failed` with the exception, since it never reaches
  the line above.

  `/healthz` and `/robots.txt` are left out unless they fail: an uptime
  monitor and Fly's own check ask every few seconds. Phoenix's own lines
  are switched off in `LumenViaeWeb.Endpoint.log_level/1`.
  """
  require Logger

  @quiet [["healthz"], ["robots.txt"]]

  def attach do
    :telemetry.attach_many(
      "lumen-viae-request-log",
      [[:phoenix, :endpoint, :stop], [:phoenix, :router_dispatch, :exception]],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @doc false
  def handle_event([:phoenix, :endpoint, :stop], %{duration: duration}, %{conn: conn}, _config) do
    status = conn.status || 0

    unless status < 500 and conn.path_info in @quiet do
      Logger.log(
        if(status >= 500, do: :error, else: :info),
        "request method=#{conn.method} path=#{conn.request_path} status=#{status} " <>
          "duration_ms=#{milliseconds(duration)}"
      )
    end
  end

  def handle_event([:phoenix, :router_dispatch, :exception], _measurements, metadata, _config) do
    %{conn: conn, kind: kind, reason: reason} = metadata

    Logger.error(
      "request_failed method=#{conn.method} path=#{conn.request_path} kind=#{kind} " <>
        "reason=#{describe(kind, reason)}"
    )
  end

  defp milliseconds(native) do
    native |> System.convert_time_unit(:native, :microsecond) |> Kernel./(1000) |> Float.round(1)
  end

  defp describe(:error, exception) when is_exception(exception),
    do: inspect(exception.__struct__) <> ": " <> first_line(Exception.message(exception))

  defp describe(_kind, reason), do: reason |> inspect(limit: 5) |> first_line()

  defp first_line(text), do: text |> String.split("\n", parts: 2) |> hd() |> String.slice(0, 200)
end
