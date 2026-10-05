defmodule LumenViae.Accounts.Admin.ConfirmActorPassword do
  @moduledoc """
  Requires the acting admin to type their own password before an account
  is added, or a password replaced, from the console.

  The console's session cookie is enough to edit content, and that is the
  right trade for content: every edit is versioned and can be put back.
  Accounts are different. A stolen cookie that could add an admin, or
  replace another admin's password, would let whoever holds it stay in
  after the real admin signs out or has their password reset, or lock the
  real admins out. Asking for the password the cookie does not carry keeps
  that door shut while the console still manages its own accounts.

  Checked in a `before_action`, against the actor's stored hash, so it runs
  only when the action really runs, not when a form is built. Attempts are
  counted per admin before the check (`LumenViae.Limits.admin_confirmation/1`):
  10 in 15 minutes per machine, so about 20 across production's two, which
  keeps a hijacked session from guessing the password at bcrypt's pace for
  long.
  """
  use Ash.Resource.Change

  alias AshAuthentication.BcryptProvider
  alias LumenViae.Accounts.Admin
  alias LumenViae.Limits

  @impl true
  def change(changeset, _opts, %{actor: %Admin{id: actor_id}} = context) do
    {rate_limit, opts} =
      actor_id
      |> Limits.admin_confirmation()
      |> Keyword.put(:on, :before_action)
      |> AshRateLimiter.BuiltinChanges.rate_limit()

    {:ok, opts} = rate_limit.init(opts)

    changeset
    |> rate_limit.change(opts, context)
    |> Ash.Changeset.before_action(&confirm(&1, actor_id))
  end

  # Only an admin may run these actions (their policies say so); without
  # one there is no password to ask for, so nothing is confirmed.
  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset,
      field: :current_password,
      message: "needs a signed-in admin"
    )
  end

  defp confirm(changeset, actor_id) do
    password = Ash.Changeset.get_argument(changeset, :current_password)

    # The actor reads itself, as any admin may read the admins. The hash is
    # left out of every admin read but AshAuthentication's and this one
    # (Admin.HidePasswordHash), so it is asked for by name.
    hash =
      case LumenViae.Accounts.get_admin(actor_id,
             actor: %Admin{id: actor_id},
             context: %{private: %{password_hash?: true}}
           ) do
        {:ok, admin} -> admin.hashed_password
        {:error, _} -> nil
      end

    if hash && BcryptProvider.valid?(password, hash) do
      changeset
    else
      # Spend the same time whether or not there was a hash to check.
      unless hash, do: BcryptProvider.simulate()

      Ash.Changeset.add_error(changeset,
        field: :current_password,
        message: "is incorrect"
      )
    end
  end
end
