defmodule LumenViae.Rosary.Completion.LookUpPlace do
  @moduledoc """
  Fills in a completion's rough place from its stored network prefix.

  The lookup is keyed by `ip_prefix`, the truncated address that is already
  on the row, not by the full address. That is what lets it run as a
  durable background job at all: the full address may never be written
  down, so it cannot travel in a job's arguments, and the stored prefix is
  all a job can know. It is also all the provider is told, so the third
  party sees no more of an address than the database does.

  Nothing is lost by it. Geolocation data is kept by network block, and an
  IPv4 /24 or an IPv6 /48 is the finest block providers place, so the
  prefix and the full address it came from resolve to the same city.

  The provider is called before the update's transaction opens, so no
  database connection waits on a third party. A lookup that comes back
  empty leaves the row as it is; one that could not be made fails the
  action, so the job is retried.
  """
  use Ash.Resource.Change

  alias LumenViae.Services.Geolocation

  @place [:city, :region, :country, :country_code]

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      case Geolocation.locate(changeset.data.ip_prefix) do
        nil ->
          changeset

        # Fails the action, so the job is retried with backoff (the
        # trigger's max_attempts) rather than finishing placeless.
        {:error, :transient} ->
          Ash.Changeset.add_error(
            changeset,
            "the geolocation provider could not be asked just now; the lookup will be retried"
          )

        location ->
          Ash.Changeset.force_change_attributes(changeset, Map.take(location, @place))
      end
    end)
  end
end
