defmodule LumenViae.Accounts.Admin.HidePasswordHash do
  @moduledoc """
  Leaves `hashed_password` out of every read of admins that is not
  AshAuthentication's own.

  Signing in needs the hash, and AshAuthentication marks its reads with
  `private.ash_authentication?`. The one other reader is
  `LumenViae.Accounts.Admin.ConfirmActorPassword`, which checks the acting
  admin's own password before an account change and asks for the hash with
  `private.password_hash?`. Private context is set only by code: no API
  can send it. Nothing else gets the hash: an admin browsing
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
      %{private: %{password_hash?: true}} -> query
      _anyone_else -> Ash.Query.deselect(query, [:hashed_password])
    end
  end
end
