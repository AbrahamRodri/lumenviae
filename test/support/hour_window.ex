defmodule LumenViae.Test.HourWindow do
  @moduledoc """
  The completion limit counts in Hammer's fixed windows of a clock hour
  (`div(now, 1 hour)`), so a test that spends a budget across the top of
  the hour starts again at zero partway through, and a completion meant to
  be refused is recorded (CI once ran one at 06:00:00). A test that spends
  the budget calls `clear_of_the_edge/0` first: it waits out the hour's
  last seconds when the test would begin in them.
  """

  @hour_ms :timer.hours(1)
  # Far more than any test that spends the budget takes.
  @edge_ms :timer.seconds(10)

  @doc "Returns at once, or after the top of the hour when it is under ten seconds away."
  def clear_of_the_edge do
    left = @hour_ms - rem(System.system_time(:millisecond), @hour_ms)
    if left < @edge_ms, do: Process.sleep(left + 50)
    :ok
  end
end
