defmodule LumenViae.Rosary.Completion.Stamp do
  @moduledoc """
  What both ways of recording a completion share: when it happened, the
  truncated network prefix it came from, and the lookup that fills in a
  rough place afterwards.

  ## The address comes from the context, never from an input

  The caller's address is read from the action context (`:client_ip`),
  which only the server can set: the REST controller and the prayer page
  pass it from `LumenViaeWeb.ClientIP`, and the GraphQL layer puts it there
  for every action. A client cannot name an address, any more than it can
  name the time it prayed. `completed_at` is the moment the action ran.

  The address is truncated by `LumenViae.Services.Geolocation.anonymize/1`
  before it is written, and only the prefix is stored. The full address
  is used in memory to decide whether a lookup is worth scheduling, and is
  never written down - not on the row, and not in the job.

  ## Why the place is filled in afterwards

  The row is written first and the geolocation lookup runs as a background
  job (the completion's `:locate` trigger) that updates it. Doing the
  lookup inline would put a third-party HTTP call between somebody
  pressing Complete and the page moving on, so a slow provider would be
  felt as a slow Rosary - and a provider that was down would fail the
  completion entirely. A place is worth having and is not worth that.

  The job is Oban's, so it survives a restart or a deploy and retries a
  failure. Its arguments are the completion's id and nothing else: the
  lookup reads the stored prefix off the row (see
  `LumenViae.Rosary.Completion.LookUpPlace`), which is how the full
  address stays out of the jobs table.

  The consequence, which is the honest trade: a row is briefly placeless
  after it is written, and stays that way for good if every attempt at
  the lookup fails.

  The job is enqueued once the write has committed, so it never looks for
  a row that is not there yet, and a job that cannot be enqueued costs the
  completion its place and nothing else.
  """
  use Ash.Resource.Change

  require Logger

  alias LumenViae.Services.Geolocation

  @impl true
  def change(changeset, _opts, _context) do
    ip = changeset.context[:client_ip]

    changeset
    |> Ash.Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
    |> Ash.Changeset.force_change_attribute(:ip_prefix, Geolocation.anonymize(ip))
    |> Ash.Changeset.after_transaction(fn
      _changeset, {:ok, completion} ->
        if locatable?(ip), do: locate_later(completion)
        {:ok, completion}

      _changeset, {:error, error} ->
        {:error, error}
    end)
  end

  # Nothing is scheduled when a lookup could not produce an answer anyway:
  # geolocation switched off, no address, or an address on a private range.
  # A job that runs only to find nothing is noise in the queue.
  defp locatable?(ip), do: is_binary(ip) and Geolocation.enabled?() and Geolocation.routable?(ip)

  # Never raises. The completion has committed and its caller is waiting to
  # hear so; a queue that cannot take the job loses this row its place, and
  # that is all it is allowed to lose.
  defp locate_later(completion) do
    case completion |> AshOban.build_trigger(:locate) |> Oban.insert() do
      {:ok, _job} -> :ok
      {:error, reason} -> log_unscheduled(completion, reason)
    end
  rescue
    exception -> log_unscheduled(completion, Exception.message(exception))
  end

  defp log_unscheduled(completion, reason) do
    Logger.warning(
      "Could not schedule a place lookup for completion #{completion.id}: #{inspect(reason)}"
    )
  end
end
