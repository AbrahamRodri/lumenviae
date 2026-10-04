defmodule LumenViae.Ops.Maintenance.RunScheduledJob do
  @moduledoc """
  Enqueues one of the crontab's workers with no arguments, as the crontab
  does. A worker the crontab does not name is refused, so the console can
  only bring the schedule forward, never invent a job.

  The job is unique while it waits wherever its worker says so
  (`Office.Jobs.WarmCache` is), so pressing the button twice queues one.
  """
  use Ash.Resource.Actions.Implementation

  alias Ash.Error.Changes.InvalidArgument
  alias LumenViae.Ops.Jobs

  @impl true
  def run(input, _opts, _context) do
    case Jobs.enqueue_scheduled(input.arguments.worker) do
      {:ok, job} ->
        {:ok, job.id}

      {:error, :not_scheduled} ->
        {:error,
         InvalidArgument.exception(
           field: :worker,
           message: "#{input.arguments.worker} is not in the crontab"
         )}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
