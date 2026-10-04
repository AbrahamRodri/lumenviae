defmodule LumenViae.Rosary.CompletionLocateSweepTest do
  @moduledoc """
  The `:locate` trigger's hourly sweep: which completions it queues a place
  lookup for, and which it leaves alone.

  A completion recorded while geolocation is off has no lookup queued
  (Completion.Stamp skips it), which is how these tests make placeless rows
  without a job already waiting for them. The sweep's own job is performed
  directly; Oban runs in manual mode, so the lookups it queues wait to be
  counted.

  Not async: the geolocation switch is application config.
  """
  use LumenViae.DataCase, async: false
  use Oban.Testing, repo: LumenViae.Repo

  import Ecto.Query, only: [from: 2]
  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completion
  alias LumenViae.Rosary.Completion.{LocateScheduler, LocateWorker}
  alias LumenViae.Services.Geolocation

  setup do
    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Sweep #{System.unique_integer([:positive])}", category: "joyful"},
        actor: admin()
      )

    %{set: set}
  end

  defp geolocation(enabled?) do
    put_env([
      {:lumen_viae, :geolocation,
       enabled: enabled?, provider: :ipapi_co, req_options: [plug: {Req.Test, Geolocation}]}
    ])
  end

  defp an_address do
    n = System.unique_integer([:positive])
    "198.51.#{rem(n, 250)}.#{rem(div(n, 250), 250) + 1}"
  end

  # Recorded with lookups off, so no job is queued for it.
  defp placeless(set, ago_hours \\ 0) do
    geolocation(false)
    {:ok, completion} = Rosary.record_completion(set.id, %{source: "web", ip: an_address()})

    if ago_hours > 0 do
      at = DateTime.utc_now() |> DateTime.add(-ago_hours * 3600) |> DateTime.truncate(:second)

      Repo.update_all(from(c in Completion, where: c.id == ^completion.id),
        set: [completed_at: at]
      )
    end

    completion
  end

  defp sweep, do: perform_job(LocateScheduler, %{})

  defp queued_ids do
    all_enqueued(worker: LocateWorker) |> Enum.map(& &1.args["primary_key"]["id"])
  end

  test "queues a lookup for a recent completion that has no place", %{set: set} do
    completion = placeless(set)
    assert queued_ids() == []

    geolocation(true)
    sweep()

    assert queued_ids() == [completion.id]
  end

  test "leaves completions older than two days alone", %{set: set} do
    recent = placeless(set, 47)
    _old = placeless(set, 49)

    geolocation(true)
    sweep()

    assert queued_ids() == [recent.id]
  end

  test "queues nothing while geolocation is switched off", %{set: set} do
    placeless(set)

    geolocation(false)
    sweep()

    assert queued_ids() == []
  end

  test "does not queue a second lookup for a completion already waiting for one", %{set: set} do
    completion = placeless(set)

    geolocation(true)
    sweep()
    sweep()

    assert queued_ids() == [completion.id]
  end

  test "leaves a completion that already has a place", %{set: set} do
    completion = placeless(set)

    Repo.update_all(from(c in Completion, where: c.id == ^completion.id),
      set: [country: "United States", country_code: "US"]
    )

    geolocation(true)
    sweep()

    assert queued_ids() == []
  end
end
