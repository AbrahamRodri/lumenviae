defmodule LumenViaeWeb.Plugs.RetryAfter do
  @moduledoc """
  Tells a client refused with a `429` how long to wait: a `Retry-After`
  header, in whole seconds, the time left in the limit's current window
  (`LumenViae.Limits.retry_after/1`).

  The limit is on the action, and what an action returns - an
  `AshRateLimiter.LimitExceeded` - carries no time, so this reads the clock
  instead: the counters are fixed windows aligned to it, so the time left is
  the same number Hammer would have given. It runs as the response is sent,
  so it needs no say in how the refusal is rendered, which is what lets REST
  and `/api/v2` (whose errors AshJsonApi renders) share it.

      plug LumenViaeWeb.Plugs.RetryAfter, window: :completion

  `window` names a limit's window (`LumenViae.Limits.window/1`). It goes on
  the routes that run that limit and no others, because a `429` from a route
  with a different window would be told the wrong time.

  The header is additive. The iOS app reads the status and nothing else
  (docs/IOS_API_CONTRACT.md), so a shipped build neither needs it nor is
  changed by it; a client that wants to back off properly now can.
  """
  import Plug.Conn

  alias LumenViae.Limits

  def init(opts), do: Keyword.fetch!(opts, :window)

  def call(conn, window) do
    register_before_send(conn, fn
      %Plug.Conn{status: 429} = conn ->
        put_resp_header(conn, "retry-after", seconds(window))

      conn ->
        conn
    end)
  end

  defp seconds(window), do: window |> Limits.window() |> Limits.retry_after() |> to_string()
end
