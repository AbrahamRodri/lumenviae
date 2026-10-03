defmodule LumenViae.Limits.Backend do
  @moduledoc """
  AshRateLimiter's `backend` for every resource that limits an action
  (the completion resource today): one hit against
  `LumenViae.Hammer`'s counters. The sign-in throttle, which is a plug, calls
  it too.

  It exists because Hammer's own module declares a `hit/3` callback of its
  own, which cannot also be declared as AshRateLimiter's.

  A hit that finds no counters table lets the request through. The table
  exists once the supervisor has started `LumenViae.Hammer`, and is briefly
  missing only while that process restarts. A rate limiter that takes the
  request down with it when it is missing is worse than one that lets the
  request through.
  """
  @behaviour AshRateLimiter.Backend

  @impl true
  def hit(key, window_ms, limit) do
    LumenViae.Hammer.hit(key, window_ms, limit)
  rescue
    ArgumentError -> {:allow, 0}
  end
end
