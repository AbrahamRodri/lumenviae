defmodule LumenViae.Limits.BackendFailOpenTest do
  @moduledoc """
  A rate limiter that takes the request down with it when its counters are
  missing is worse than one that lets the request through. They are missing
  only while `LumenViae.Hammer` restarts.

  Not async: it stops the counters, which every other test spends.
  """
  use ExUnit.Case, async: false

  alias LumenViae.Limits.Backend

  test "lets the request through while the counters table does not exist" do
    :ok = Supervisor.terminate_child(LumenViae.Supervisor, LumenViae.Hammer)
    on_exit(fn -> Supervisor.restart_child(LumenViae.Supervisor, LumenViae.Hammer) end)

    assert {:allow, 0} =
             Backend.hit("test:missing:#{System.unique_integer([:positive])}", 1_000, 1)
  end
end
