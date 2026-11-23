defmodule LumenViae.Ops.Runtime do
  @moduledoc """
  This machine as the VM sees it, and the Office cache on every machine.
  """

  alias LumenViae.Ops.{Health, Jobs}

  @doc """
  The release and the VM. `commit` is the git commit the release was
  deployed from (`Health.commit/0`, "unknown" off the server), and
  `started_at` when this VM started: each deploy starts a new container, so
  it is when the running release went live.
  """
  def snapshot do
    {uptime_ms, _since_last} = :erlang.statistics(:wall_clock)
    uptime_seconds = div(uptime_ms, 1000)

    %{
      version: Health.version(),
      commit: Health.commit(),
      started_at: DateTime.add(DateTime.utc_now(), -uptime_seconds, :second),
      elixir: System.version(),
      otp: System.otp_release(),
      node: node(),
      peers: Node.list(),
      uptime_seconds: uptime_seconds,
      memory: Map.new(:erlang.memory()),
      processes: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      schedulers: :erlang.system_info(:schedulers_online),
      run_queue: :erlang.statistics(:total_run_queue_lengths)
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

    %{machines: machines, last_warm: Jobs.last_run(LumenViae.Office.warm_cache_worker())}
  end
end
