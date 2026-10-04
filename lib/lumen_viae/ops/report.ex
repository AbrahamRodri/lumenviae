defmodule LumenViae.Ops.Report do
  @moduledoc """
  The job queues as plain text, for `mix lumen_viae.jobs` on a laptop and
  the matching `LumenViae.Release` functions in a production shell, so
  both print the same thing. Every function answers a string.
  """

  alias LumenViae.Ops

  @columns [
    {"available", "waiting"},
    {"scheduled", "sched"},
    {"executing", "running"},
    {"retryable", "retrying"},
    {"discarded", "discarded"},
    {"cancelled", "cancelled"},
    {"completed", "done/7d"}
  ]

  @doc "One line per queue, its limit and its count in each state."
  def queues(rows \\ Ops.queues()) do
    header = ["queue", "limit" | Enum.map(@columns, &elem(&1, 1))]

    body =
      Enum.map(rows, fn row ->
        [row.queue, to_string(row.limit || "-")] ++
          Enum.map(@columns, fn {state, _label} -> to_string(Map.get(row.counts, state, 0)) end)
      end)

    table([header | body])
  end

  @doc "The recent failures, one block each."
  def failures(jobs) do
    if jobs == [] do
      "Nothing has failed in the last seven days."
    else
      Enum.map_join(jobs, "\n", fn job ->
        "##{job.id} #{job.worker} [#{job.queue}] #{job.state}, attempt #{job.attempt}/#{job.max_attempts}, " <>
          "#{stamp(job.attempted_at)}\n    #{job.error || "(no error recorded)"}"
      end)
    end
  end

  @doc "How one job stands: its state, and its last error if it has one."
  def job_status(job) do
    error = if job.error, do: "\n    #{job.error}", else: ""
    "##{job.id} #{job.worker}: #{job.state}, attempt #{job.attempt}/#{job.max_attempts}#{error}"
  end

  @doc "The crontab, with when each entry runs next and how it last went."
  def schedule(entries) do
    if entries == [] do
      "Nothing is scheduled."
    else
      rows =
        Enum.map(entries, fn entry ->
          [
            entry.expression,
            entry.worker,
            if(entry.next_at, do: stamp(entry.next_at), else: "at boot"),
            last_run(entry.last_run),
            if(entry.running_here?, do: "", else: "(not running on this node)")
          ]
        end)

      table([["when", "worker", "next run (UTC)", "last run", ""] | rows])
    end
  end

  defp last_run(nil), do: "never (7 days)"

  defp last_run(run),
    do: "#{run.state} #{stamp(run.attempted_at || run.inserted_at)} (##{run.id})"

  defp stamp(nil), do: "-"

  defp stamp(%DateTime{} = at),
    do: at |> DateTime.truncate(:second) |> Calendar.strftime("%Y-%m-%d %H:%M:%S")

  defp table(rows) do
    widths =
      rows
      |> Enum.zip_with(& &1)
      |> Enum.map(fn column -> column |> Enum.map(&String.length/1) |> Enum.max() end)

    Enum.map_join(rows, "\n", fn row ->
      row
      |> Enum.zip(widths)
      |> Enum.map_join("  ", fn {cell, width} -> String.pad_trailing(cell, width) end)
      |> String.trim_trailing()
    end)
  end
end
