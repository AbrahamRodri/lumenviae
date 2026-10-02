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
  lives in memory long enough to key the lookup, and is never written down.

  ## Why the place is filled in afterwards

  The row is written first and the geolocation lookup runs in a background
  task that updates it. Doing the lookup inline would put a third-party
  HTTP call between somebody pressing Complete and the page moving on, so a
  slow provider would be felt as a slow Rosary - and a provider that was
  down would fail the completion entirely. A place is worth having and is
  not worth that.

  The consequence, which is the honest trade: a row is briefly placeless
  after it is written, and stays that way for good if the lookup fails.

  The task is started once the write has committed, so it never looks for a
  row that is not there yet.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias LumenViae.Services.Geolocation

  @impl true
  def change(changeset, _opts, _context) do
    ip = changeset.context[:client_ip]

    changeset
    |> Ash.Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
    |> Ash.Changeset.force_change_attribute(:ip_prefix, Geolocation.anonymize(ip))
    |> Ash.Changeset.after_transaction(fn
      _changeset, {:ok, completion} ->
        locate_later(completion.id, ip)
        {:ok, completion}

      _changeset, {:error, error} ->
        {:error, error}
    end)
  end

  # Nothing is scheduled when a lookup could not produce an answer anyway:
  # geolocation switched off, no address, or an address on a private range.
  # A task that starts only to return `nil` is noise in the supervisor.
  defp locate_later(completion_id, ip) do
    if is_binary(ip) and Geolocation.enabled?() and Geolocation.routable?(ip) do
      Task.Supervisor.start_child(LumenViae.TaskSupervisor, fn ->
        case Geolocation.locate(ip) do
          nil -> :ok
          location -> place(completion_id, location)
        end
      end)
    end

    :ok
  end

  # Unauthorized on purpose: this is the server writing down what it looked
  # up, after the response has gone, with nobody left to act as. :place is
  # the console's to call otherwise.
  #
  # Returns `:ok` whatever happens. This runs well after the completion was
  # reported, and by then there is nobody left to tell: the row may have
  # been deleted with its set, or the lookup may disagree with the
  # resource. Neither is worth crashing a task over.
  defp place(completion_id, location) do
    LumenViae.Rosary.Completion
    |> Ash.Query.filter(id == ^completion_id)
    |> Ash.bulk_update(:place, Map.take(location, [:city, :region, :country, :country_code]),
      authorize?: false
    )

    :ok
  end
end
