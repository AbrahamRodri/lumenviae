defmodule LumenViae.Ops.Runtime do
  @moduledoc """
  This machine as the VM sees it, and the Office cache on every machine.
  """

  alias LumenViae.Ops.{Health, Jobs}

  @doc "The release, the VM and where it is running."
  def snapshot do
    {uptime_ms, _since_last} = :erlang.statistics(:wall_clock)

    %{
      version: Health.version(),
      elixir: System.version(),
      otp: System.otp_release(),
      node: node(),
      peers: Node.list(),
      uptime_seconds: div(uptime_ms, 1000),
      memory: Map.new(:erlang.memory()),
      processes: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      schedulers: :erlang.system_info(:schedulers_online),
      run_queue: :erlang.statistics(:total_run_queue_lengths),
      region: System.get_env("FLY_REGION"),
      machine: System.get_env("FLY_MACHINE_ID"),
      image: System.get_env("FLY_IMAGE_REF")
    }
  end

  @doc """
  Each machine's Office cache, `[{node, %{entries:, bytes:} | {:error, reason}}]`,
  this one first, and the cache warming job's last run.
  """
  def office_cache do
    nodes = [node() | Node.list()]

    machines =
      nodes
      |> :erpc.multicall(LumenViae.Office, :cache_stats, [], :timer.seconds(5))
      |> Enum.zip(nodes)
      |> Enum.map(fn
        {{:ok, stats}, node} -> {node, stats}
        {{_class, reason}, node} -> {node, {:error, reason}}
      end)

    %{machines: machines, last_warm: Jobs.last_run(LumenViae.Office.Jobs.WarmCache)}
  end
end
