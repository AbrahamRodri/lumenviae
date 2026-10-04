defmodule LumenViae.Accounts.Admin.HidePasswordHash do
  @moduledoc """
  Leaves `hashed_password` out of every read of admins that is not
  AshAuthentication's own.

  Signing in needs the hash, and AshAuthentication marks its reads with
  `private.ash_authentication?`. Nothing else does: an admin browsing
  admins in AshAdmin's data browser would otherwise be sent the hash
  behind a "show" toggle. A field policy cannot do this, because Ash
  applies field policies to public attributes only, and the hash is not
  public.
  """
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, _context) do
    case query.context do
      %{private: %{ash_authentication?: true}} -> query
      _anyone_else -> Ash.Query.deselect(query, [:hashed_password])
    end
  end
end
