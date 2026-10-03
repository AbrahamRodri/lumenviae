defmodule LumenViae.Limits.BackendTest do
  @moduledoc """
  The counters every rate limit spends (`LumenViae.Hammer`, through
  `LumenViae.Limits.Backend`): the behaviour the application's own
  fixed-window counter had, which these tests were written for, held by
  Hammer's ETS backend now.

  Every test keys on its own bucket. The table is global and the suite is
  async, so sharing a key between tests would make one test's traffic show
  up as another's failure.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Limits.Backend

  defp hit(key, limit, window_ms), do: Backend.hit(key, window_ms, limit)

  defp allowed?(result), do: match?({:allow, _}, result)

  test "allows exactly the limit, then refuses" do
    key = "test:allows:#{System.unique_integer([:positive])}"

    for _ <- 1..3 do
      assert allowed?(hit(key, 3, :timer.hours(1)))
    end

    assert {:deny, _retry_in_ms} = hit(key, 3, :timer.hours(1))
  end

  test "keeps refusing once past the limit, rather than letting the next one through" do
    key = "test:stays:#{System.unique_integer([:positive])}"

    assert allowed?(hit(key, 1, :timer.hours(1)))

    for _ <- 1..5 do
      assert {:deny, _} = hit(key, 1, :timer.hours(1))
    end
  end

  test "one key's traffic does not count against another's" do
    a = "test:a:#{System.unique_integer([:positive])}"
    b = "test:b:#{System.unique_integer([:positive])}"

    assert allowed?(hit(a, 1, :timer.hours(1)))
    assert {:deny, _} = hit(a, 1, :timer.hours(1))

    assert allowed?(hit(b, 1, :timer.hours(1)))
  end

  test "a new window starts a fresh budget" do
    key = "test:window:#{System.unique_integer([:positive])}"

    # A one millisecond window is its own next window by the time the
    # second call lands.
    assert allowed?(hit(key, 1, 1))
    Process.sleep(5)
    assert allowed?(hit(key, 1, 1))
  end

  test "windows of different sizes do not collide" do
    key = "test:sizes:#{System.unique_integer([:positive])}"

    assert allowed?(hit(key, 1, :timer.hours(1)))
    assert allowed?(hit(key, 1, :timer.minutes(1)))

    # And each size still keeps its own count.
    assert {:deny, _} = hit(key, 1, :timer.hours(1))
    assert {:deny, _} = hit(key, 1, :timer.minutes(1))
  end

  test "says how long until the window ends, so a caller could be told" do
    key = "test:retry:#{System.unique_integer([:positive])}"

    hit(key, 1, :timer.hours(1))

    assert {:deny, retry_in_ms} = hit(key, 1, :timer.hours(1))
    assert retry_in_ms > 0 and retry_in_ms <= :timer.hours(1)
  end
end
