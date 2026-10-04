defmodule LumenViae.Ops.Maintenance do
  @moduledoc """
  What the console can do to the running app, as generic actions with no
  table: enqueue a scheduled job now, and empty every machine's Office
  cache. Reached through `LumenViae.Ops`'s code interface.

  An admin may run either; nobody else may run anything. There is no public
  door to this resource (no GraphQL, no JSON:API), so the policy is the
  only thing between a caller and an act, and it says so plainly.

  Only a worker named in the crontab can be run, so the console's "Run
  now" can never enqueue an arbitrary module or arguments: it does what
  the schedule would have done, earlier.
  """
  use Ash.Resource,
    domain: LumenViae.Ops,
    authorizers: [Ash.Policy.Authorizer]

  alias LumenViae.Ops.Maintenance.{ClearOfficeCache, RunScheduledJob}

  actions do
    action :run_scheduled_job, :integer do
      description "Enqueues a job the crontab runs, now, and answers its id."

      argument :worker, :string do
        allow_nil? false
        description "The worker's module name, one of LumenViae.Ops.scheduled_workers/0."
      end

      run RunScheduledJob
    end

    action :clear_office_cache, :integer do
      description "Empties the Office cache on every machine, and answers how many answered."
      run ClearOfficeCache
    end
  end

  policies do
    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end
end
