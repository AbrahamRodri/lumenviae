defmodule LumenViae.OpsTest do
  @moduledoc """
  The Ops domain against the suite's own database and Oban, which runs in
  manual mode: jobs are inserted and nothing runs them, so the counts and
  failures below are exactly the rows each test writes.
  """
  use LumenViae.DataCase, async: true
  use Oban.Testing, repo: LumenViae.Repo

  alias LumenViae.Ops
  alias LumenViae.Office.Jobs.WarmCache
  alias LumenViae.Repo

  defp insert_job(attrs) do
    defaults = %{
      worker: "LumenViae.Test.Worker",
      queue: "maintenance",
      args: %{},
      state: "available",
      attempt: 0,
      max_attempts: 3,
      errors: []
    }

    Repo.insert!(struct(Oban.Job, Map.merge(defaults, attrs)))
  end

  describe "health/1" do
    test "is ok when the database answers, and says no more than that" do
      assert %{status: "ok", db: "ok", version: version} = Ops.health()
      assert version == to_string(Application.spec(:lumen_viae, :vsn))
      assert Ops.health() |> Map.keys() |> Enum.sort() == [:db, :status, :version]
    end
  end

  describe "runtime/0 and database/1" do
    test "describe this machine and its database" do
      runtime = Ops.runtime()
      assert runtime.node == node()
      assert runtime.memory.total > 0
      assert runtime.processes > 0

      database = Ops.database(tables: 3)
      assert database.size_bytes > 0
      assert database.connections >= 1
      assert database.pool_size > 0
      assert length(database.tables) <= 3
      assert Enum.all?(database.tables, &(is_binary(&1.name) and &1.bytes >= 0))
    end
  end

  describe "queues/0" do
    test "counts each queue's jobs by state, with the configured queues listed" do
      insert_job(%{state: "available"})
      insert_job(%{state: "available"})
      insert_job(%{state: "discarded", queue: "geolocation"})

      queues = Map.new(Ops.queues(), &{&1.queue, &1})

      assert queues["maintenance"].counts["available"] == 2
      assert queues["maintenance"].oldest_available_at
      assert queues["geolocation"].counts["discarded"] == 1
      assert Map.has_key?(queues, "elevenlabs")
    end
  end

  describe "recent_failures/1" do
    test "lists failed jobs newest first with the first line of the last error" do
      insert_job(%{
        state: "discarded",
        attempt: 3,
        attempted_at: DateTime.utc_now(),
        errors: [%{"attempt" => 3, "at" => "x", "error" => "boom\nstacktrace line"}]
      })

      insert_job(%{state: "completed"})

      assert [failure] = Ops.recent_failures(5)
      assert failure.state == "discarded"
      assert failure.error == "boom"
    end
  end

  describe "schedule/1" do
    test "lists the production crontab, not running under the suite" do
      entries = Ops.schedule(~U[2026-10-03 23:00:00Z])

      assert %{next_at: nil, running_here?: false} =
               Enum.find(entries, &(&1.expression == "@reboot"))

      assert %{next_at: next_at} = Enum.find(entries, &(&1.expression == "7 0,12 * * *"))
      assert next_at == ~U[2026-10-04 00:07:00Z]

      assert Ops.scheduled_workers() == [
               inspect(WarmCache),
               "LumenViae.Rosary.Completion.LocateScheduler"
             ]

      assert %{expression: "23 * * * *"} =
               Enum.find(entries, &(&1.worker == "LumenViae.Rosary.Completion.LocateScheduler"))
    end

    test "names a worker's last run" do
      job = insert_job(%{worker: inspect(WarmCache), state: "completed"})
      assert %{id: id, state: "completed"} = Ops.last_run(WarmCache)
      assert id == job.id
    end
  end

  describe "run_scheduled_job/2" do
    test "an admin can run a crontab worker now" do
      assert {:ok, id} = Ops.run_scheduled_job(inspect(WarmCache), actor: admin())
      assert is_integer(id)
      assert_enqueued(worker: WarmCache, queue: :maintenance)
    end

    test "nobody else can" do
      assert {:error, %Ash.Error.Forbidden{}} = Ops.run_scheduled_job(inspect(WarmCache))
      refute_enqueued(worker: WarmCache)
    end

    test "a worker the crontab does not name is refused" do
      assert {:error, error} =
               Ops.run_scheduled_job("LumenViae.Curation.Jobs.NarrateMeditation", actor: admin())

      assert Exception.message(error) =~ "not in the crontab"
    end
  end

  describe "clear_office_cache/1" do
    test "an admin can, and it answers how many machines did it" do
      assert {:ok, 1} = Ops.clear_office_cache(actor: admin())
    end

    test "nobody else can" do
      assert {:error, %Ash.Error.Forbidden{}} = Ops.clear_office_cache()
    end
  end

  describe "retry_jobs/1 and cancel_job/1" do
    test "retry makes a failed job available again" do
      job = insert_job(%{state: "discarded", attempt: 3})
      assert {:ok, 1} = Ops.retry_jobs(id: job.id)
      assert Repo.get(Oban.Job, job.id).state == "available"
    end

    test "retry by queue takes retryable and discarded jobs, not cancelled ones" do
      retryable = insert_job(%{state: "retryable", queue: "geolocation", attempt: 1})
      cancelled = insert_job(%{state: "cancelled", queue: "geolocation", attempt: 1})

      assert {:ok, 1} = Ops.retry_jobs(queue: "geolocation")
      assert Repo.get(Oban.Job, retryable.id).state == "available"
      assert Repo.get(Oban.Job, cancelled.id).state == "cancelled"
    end

    test "cancel cancels a waiting job, and both say when there is no such job" do
      job = insert_job(%{state: "available"})
      assert :ok = Ops.cancel_job(job.id)
      assert Repo.get(Oban.Job, job.id).state == "cancelled"

      assert {:error, :not_found} = Ops.cancel_job(-1)
      assert {:error, :not_found} = Ops.retry_jobs(id: -1)
    end
  end

  describe "probes" do
    test "report geolocation's switch and ElevenLabs' key without calling either" do
      assert %{status: :off, ms: ms} = Ops.probe(:geolocation)
      assert is_integer(ms)
      assert %{status: status} = Ops.probe(:elevenlabs)
      assert status in [:ok, :off]
    end
  end
end
