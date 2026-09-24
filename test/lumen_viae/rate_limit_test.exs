defmodule LumenViae.RateLimitTest do
  @moduledoc """
  Every test keys on its own bucket. The table is global and the suite is
  async, so sharing a key between tests would make one test's traffic show
  up as another's failure.
  """
  use ExUnit.Case, async: true

  alias LumenViae.RateLimit

  test "allows exactly the limit, then refuses" do
    key = "test:allows:#{System.unique_integer([:positive])}"

    for _ <- 1..3 do
      assert RateLimit.check(key, 3, :timer.hours(1)) == :ok
    end

    assert RateLimit.check(key, 3, :timer.hours(1)) == {:error, :rate_limited}
  end

  test "keeps refusing once past the limit, rather than letting the next one through" do
    key = "test:stays:#{System.unique_integer([:positive])}"

    assert RateLimit.check(key, 1, :timer.hours(1)) == :ok

    for _ <- 1..5 do
      assert RateLimit.check(key, 1, :timer.hours(1)) == {:error, :rate_limited}
    end
  end

  test "one key's traffic does not count against another's" do
    a = "test:a:#{System.unique_integer([:positive])}"
    b = "test:b:#{System.unique_integer([:positive])}"

    assert RateLimit.check(a, 1, :timer.hours(1)) == :ok
    assert RateLimit.check(a, 1, :timer.hours(1)) == {:error, :rate_limited}

    assert RateLimit.check(b, 1, :timer.hours(1)) == :ok
  end

  test "a new window starts a fresh budget" do
    key = "test:window:#{System.unique_integer([:positive])}"

    # A one millisecond window is its own next window by the time the
    # second call lands.
    assert RateLimit.check(key, 1, 1) == :ok
    Process.sleep(5)
    assert RateLimit.check(key, 1, 1) == :ok
  end

  test "windows of different sizes do not collide" do
    key = "test:sizes:#{System.unique_integer([:positive])}"

    # The top of an hour, where the one-hour and one-minute windows start
    # on the same millisecond. Keyed by start alone, the second call would
    # inherit the first's count and be refused.
    top_of_hour = :timer.hours(500_000)

    assert RateLimit.check(key, 1, :timer.hours(1), top_of_hour) == :ok
    assert RateLimit.check(key, 1, :timer.minutes(1), top_of_hour) == :ok

    # And each size still keeps its own count.
    assert RateLimit.check(key, 1, :timer.hours(1), top_of_hour) == {:error, :rate_limited}
    assert RateLimit.check(key, 1, :timer.minutes(1), top_of_hour) == {:error, :rate_limited}
  end
end
