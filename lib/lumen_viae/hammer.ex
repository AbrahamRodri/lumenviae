defmodule LumenViae.Hammer do
  @moduledoc """
  The counters behind every rate limit in the application: Hammer's ETS
  backend, with its fixed-window algorithm. AshRateLimiter reaches it through
  `LumenViae.Limits.Backend`, which the completion resource names as
  its `backend` and the sign-in throttle (`LumenViaeWeb.Plugs.ThrottleSignIn`)
  calls directly. Nothing else touches the counters.

  This is deliberately the smallest thing that works, and it is per-machine
  rather than shared. **Production runs two machines**, so each holds its
  own counters and the effective ceiling is twice the number configured: a
  caller landing on one machine and then the other gets both budgets.

  That is accepted rather than overlooked. The completion limit exists to
  stop a script writing thousands of rows, and 40 an hour stops that as well
  as 20 does against a site seeing between one and two a day; the sign-in
  limits exist to make guessing a password slow, and twice a slow rate is
  still slow. What it is not is a precise quota, and it should not be
  described as one.

  If it ever needs to be exact, the honest fix is a shared store - a
  Postgres table or Redis, which AshRateLimiter takes as another backend -
  rather than dividing the number by the machine count and pretending this
  is distributed, which breaks the moment the count changes or the load
  balancer stops splitting traffic evenly.

  A fixed window lets a caller spend the whole budget at the very end of one
  window and again at the start of the next. That burst is fine here: the
  limits exist to stop scripts, not to smooth traffic, and a doubled burst
  is still orders of magnitude short of what they are there to stop.

  Hammer keys a window by the key and the window's index
  (`div(now, window)`), so two limits that share a key and a window size
  would meet in one counter. Every limit therefore has its own key prefix
  (`completion:`, `sign_in_ip:`, `sign_in_email:`), and a new one must too.

  Started in the supervision tree with `clean_period`, which is how often
  expired windows are swept; the table is small enough that ten minutes is
  plenty.
  """
  use Hammer, backend: :ets
end
