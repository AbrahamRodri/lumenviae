defmodule LumenViae.RateLimit do
  @moduledoc """
  A fixed-window counter in ETS, used to cap how often one caller can write
  a completion.

  This is deliberately the smallest thing that works, and it is per-machine
  rather than shared. **Production now runs two machines**, so each holds
  its own counters and the effective ceiling is twice the number passed in:
  a caller landing on one machine and then the other gets both budgets.

  That is accepted rather than overlooked. The limit exists to stop a script
  writing thousands of completions, and 40 an hour stops that as well as 20
  does against a site seeing between one and two a day. What it is not is a
  precise quota, and it should not be described as one.

  If it ever needs to be exact, the honest fix is a shared store - a
  Postgres table or Redis - rather than dividing the number by the machine
  count and pretending this is distributed, which breaks the moment the
  count changes or the load balancer stops splitting traffic evenly.

  A fixed window lets a caller spend the whole budget at the very end of
  one window and again at the start of the next. That burst is fine here:
  the limit exists to stop a script writing thousands of completions, not
  to smooth traffic, and a doubled burst is still three orders of magnitude
  short of that.
  """

  use GenServer

  @table :lumen_viae_rate_limit

  # Sweeping only has to be faster than memory grows. Every entry is a
  # short binary and four integers, and the table is swept whole.
  @sweep_interval_ms :timer.minutes(10)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Counts one event against `key` and says whether it is still under
  `limit` for the current `window_ms` window.

  `now` is the current time in milliseconds. Callers leave it out; tests
  pass it so they can put a call at a chosen point in a window rather than
  wherever the wall clock happens to be.

  Returns `:ok`, or `{:error, :rate_limited}` once the limit is passed.
  Counting happens either way, so a caller that keeps hammering stays
  blocked for the rest of the window rather than being let through the
  moment it stops.
  """
  def check(key, limit, window_ms, now \\ now_ms())

  def check(key, limit, window_ms, now)
      when is_binary(key) and is_integer(limit) and is_integer(window_ms) and is_integer(now) do
    # The window is keyed by its size and the millisecond it started, not by
    # an index. An index is only meaningful next to the window size that
    # produced it, so two callers using different sizes would write indices
    # that cannot be compared - and the sweep has to compare them. The start
    # alone is not enough either: every size that divides the hour starts a
    # window at the top of it, so a one-minute and a one-hour window would
    # share a row for that first minute and each inherit the other's count.
    window_start = div(now, window_ms) * window_ms
    expires_at = window_start + window_ms
    row_key = {key, window_ms, window_start}

    count =
      :ets.update_counter(
        @table,
        row_key,
        {2, 1},
        {row_key, 0, expires_at}
      )

    if count > limit, do: {:error, :rate_limited}, else: :ok
  rescue
    # The table only exists once the supervisor has started this process.
    # A rate limiter that takes the request down with it when it is missing
    # is worse than one that lets the request through.
    ArgumentError -> :ok
  end

  @doc """
  Drops every counter. For tests, so one test's traffic cannot exhaust the
  budget another test is asserting on.
  """
  def reset do
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep()
    schedule_sweep()
    {:noreply, state}
  end

  # A window that has expired is finished being counted and can never be
  # read again, because `check/3` only ever looks at the window it is in.
  # Each row carries its own expiry so this holds whatever window sizes the
  # callers happen to be using.
  defp sweep do
    now = now_ms()
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)

  defp now_ms, do: System.system_time(:millisecond)
end
