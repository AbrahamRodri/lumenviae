defmodule LumenViae.Ops do
  @moduledoc """
  The app looking at itself: the release, the database, the job queues, the
  Office cache and the third parties, for the console's System screen,
  `GET /healthz`, `mix lumen_viae.doctor`, `mix lumen_viae.jobs` and the
  matching `LumenViae.Release` functions.

  Like `LumenViae.Office`, it owns no tables. What it reads is Postgres's
  own catalogs, Oban's jobs table and the running VM, none of which is
  Rosary data, so its readers live under `lib/lumen_viae/ops/` and may use
  the Repo (`test/lumen_viae/rosary/context_rules_test.exs` exempts the
  directory, as it does the Office).

  ## Reads are functions, acts are actions

  Reading what the app is doing changes nothing, so the reads are plain
  functions, delegated below. The two things the console can *do* - enqueue
  a scheduled job now, empty the Office cache - are generic actions on
  `LumenViae.Ops.Maintenance`, called through this domain's code interface
  with the admin as actor, so the policies decide who may, as they do for
  every write in the app. The release and mix tasks call the same actions
  as the operator, with `authorize?: false`, like every other release task.
  """
  use Ash.Domain, otp_app: :lumen_viae

  alias LumenViae.Ops.{Database, Health, Jobs, Probes, Runtime}

  resources do
    resource LumenViae.Ops.Maintenance do
      define :run_scheduled_job, action: :run_scheduled_job, args: [:worker]
      define :clear_office_cache, action: :clear_office_cache
    end
  end

  defdelegate health(opts \\ []), to: Health, as: :check
  defdelegate runtime, to: Runtime, as: :snapshot
  defdelegate database(opts \\ []), to: Database, as: :snapshot
  defdelegate queues, to: Jobs
  defdelegate recent_failures(limit \\ 10), to: Jobs
  defdelegate schedule(now \\ DateTime.utc_now()), to: Jobs
  defdelegate scheduled_workers, to: Jobs
  defdelegate last_run(worker), to: Jobs
  defdelegate job(id), to: Jobs, as: :get
  defdelegate retry_jobs(filter), to: Jobs, as: :retry
  defdelegate cancel_job(id), to: Jobs, as: :cancel
  defdelegate office_cache, to: Runtime
  defdelegate probe(name), to: Probes, as: :run
  defdelegate probe_names, to: Probes, as: :names
end
