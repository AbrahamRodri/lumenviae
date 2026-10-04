defmodule Mix.Tasks.LumenViae.JobsTest do
  @moduledoc """
  The task's commands against the suite's database, with Mix's shell
  swapped for one that sends its output to the test.
  """
  use LumenViae.DataCase, async: false
  use Oban.Testing, repo: LumenViae.Repo

  alias LumenViae.Office.Jobs.WarmCache
  alias Mix.Tasks.LumenViae.Jobs

  setup do
    shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(shell) end)
  end

  defp said do
    receive do
      {:mix_shell, :info, [text]} -> text
    after
      0 -> flunk("the task printed nothing")
    end
  end

  test "with no command, prints the queues" do
    Jobs.run([])
    assert said() =~ ~r/^queue\s+limit\s+waiting/
  end

  test "schedule prints the crontab" do
    Jobs.run(["schedule"])
    assert said() =~ inspect(WarmCache)
  end

  test "cancel and retry act on one job by id" do
    {:ok, job} = Oban.insert(WarmCache.new(%{}))

    Jobs.run(["cancel", "--id", to_string(job.id)])
    assert said() =~ "Job #{job.id} cancelled"

    Jobs.run(["retry", "--id", to_string(job.id)])
    assert said() =~ "1 job(s) made available again"
  end

  test "run refuses a worker the crontab does not name" do
    assert_raise Mix.Error, ~r/not in the crontab/, fn -> Jobs.run(["run", "Nope"]) end
    refute_enqueued(worker: WarmCache)
  end

  test "an unknown command says where the help is" do
    assert_raise Mix.Error, ~r/mix help lumen_viae.jobs/, fn -> Jobs.run(["nope"]) end
  end
end
