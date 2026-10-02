defmodule LumenViae.Accounts do
  @moduledoc """
  The console's admin accounts: who may sign in to `/admin`, and the
  session tokens that prove it.

  The domain's only public entry point, as `LumenViae.Rosary` is for the
  Rosary. Its resources are `LumenViae.Accounts.Admin` and
  `LumenViae.Accounts.Token`; sign-in itself is AshAuthentication's, through
  the routes `LumenViaeWeb.Router` declares for the admin resource.

  There is no sign-up. Admins are made, and their passwords replaced, from
  a production shell (`LumenViae.Release.create_admin/1`,
  `LumenViae.Release.reset_admin_password/1`), which runs these functions
  with `authorize?: false` because whoever holds that shell already holds
  the database. See docs/PROD_ACCESS.md.
  """
  use Ash.Domain,
    otp_app: :lumen_viae,
    extensions: [AshAdmin.Domain]

  # Browsable at /admin/data with the rest. Tokens are hidden there by
  # their policies: only AshAuthentication may read them.
  admin do
    show?(true)
  end

  resources do
    resource LumenViae.Accounts.Admin do
      define :create_admin, action: :create, args: [:email, :password]
      define :set_admin_password, action: :set_password, args: [:password]
      define :get_admin_by_email, action: :get_by_email, args: [:email], get?: true
    end

    resource LumenViae.Accounts.Token
  end

  @dev_admin_email "dev-admin@lumenviae.local"

  @doc """
  The email of the admin `priv/repo/seeds.exs` creates in development, and
  that `:skip_admin_auth` signs in as. Never created anywhere else.
  """
  def dev_admin_email, do: @dev_admin_email

  @doc """
  A password for a new admin or a reset: 24 random bytes, URL-safe Base64,
  so 32 characters with no ambiguity about where it ends when printed.
  """
  def generate_password do
    24 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
