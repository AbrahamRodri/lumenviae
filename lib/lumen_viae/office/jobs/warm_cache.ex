defmodule LumenViae.Office.Jobs.WarmCache do
  @moduledoc """
  Fills every machine's Office cache with the days about to be asked for,
  so the first iOS request of a day is not the one that waits on the
  engine.

  The cache is an ETS table on each machine (`LumenViae.Office.Cache`), and
  a deploy empties it. This job runs on the `maintenance` queue of
  whichever machine fetched it and asks every machine in the cluster,
  itself included, to warm its own copy (`LumenViae.Office.warm/1` through
  `:erpc.multicall/5`), so one job warms both production machines. An
  unclustered machine warms only itself; the other fills on demand as it
  always has.

  Enqueued by the crontab (`config/config.exs`): at boot, and twice a day.
  The days are yesterday through two days ahead in UTC, which covers
  "today" in every time zone an iPhone can be set to: 4 dates, 32 hours
  and the one or two months they fall in. Anything already cached is
  skipped, so a run after the first costs a handful of new fetches.
  Arguments: none, or `days_ahead` to warm further.

  ## When the engine cannot be reached

  The engine is its own Fly app, suspended while idle, so a run also wakes
  it. A machine stops warming at its first failed fetch (the engine
  client's own warning for that one request is the only other line), so a
  run against a dead engine asks once per machine, not thirty-odd times.
  A run with any failure - an engine that did not answer, or a machine
  that did not answer in time - logs one line naming every machine's
  result and fails, and Oban tries again 15 and then 30 minutes later,
  three attempts in all. It never loops: failures are not cached (a miss
  stays a miss and is fetched on demand as before), and the job is unique
  while it waits, so the next cron run cannot stack a second one behind a
  retry.
  """
  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    unique: [period: :infinity, states: :incomplete]

  require Logger

  @default_days_ahead 2
  # Each machine fetches its misses one at a time; 32 hours and two months
  # against a self-hosted engine is well inside this, and a machine that
  # does not answer by then is reported, not waited on.
  @per_node_timeout :timer.minutes(4)

  @impl Oban.Worker
  def timeout(_job), do: @per_node_timeout + :timer.seconds(30)

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}), do: 15 * 60 * attempt

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    dates = dates(Date.utc_today(), Map.get(args, "days_ahead", @default_days_ahead))
    results = warm_every_node(dates, [node() | Node.list()], @per_node_timeout)
    summary = Enum.map_join(results, "; ", &describe/1)

    if Enum.all?(results, &warmed?/1) do
      Logger.info("Office cache warmed: #{summary}")
      :ok
    else
      Logger.warning("Office cache warm incomplete: #{summary}")
      {:error, "Office cache warm incomplete: #{summary}"}
    end
  end

  @doc """
  Warms `dates` on each of `nodes`, giving each `timeout` milliseconds.
  Answers `{node, counts}` for a machine that warmed, and
  `{node, {:error, reason}}` for one that raised or did not answer in time
  (`{:erpc, :timeout}`, `{:erpc, :noconnection}`).
  """
  def warm_every_node(dates, nodes, timeout) do
    nodes
    |> :erpc.multicall(LumenViae.Office, :warm, [dates], timeout)
    |> Enum.zip(nodes)
    |> Enum.map(fn
      {{:ok, counts}, node} -> {node, counts}
      {{_class, reason}, node} -> {node, {:error, reason}}
    end)
  end

  @doc "The dates a run warms: yesterday through `days_ahead` days after `today`."
  def dates(%Date{} = today, days_ahead) when is_integer(days_ahead) and days_ahead >= 0 do
    Enum.map(-1..days_ahead, &Date.add(today, &1))
  end

  defp warmed?({_node, %{failed: 0}}), do: true
  defp warmed?(_failed_or_unanswered), do: false

  defp describe({node, {:error, reason}}), do: "#{node} did not answer (#{inspect(reason)})"

  defp describe({node, counts}) do
    "#{node} #{counts.warmed} fetched, #{counts.cached} already cached, " <>
      "#{counts.failed} failed, #{counts.skipped} skipped"
  end
end
