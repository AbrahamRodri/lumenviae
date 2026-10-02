defmodule LumenViae.Accounts.Secrets do
  @moduledoc """
  Hands AshAuthentication the secret that signs admin session tokens.

  Read from `config :lumen_viae, :token_signing_secret` at call time:
  dev.exs and test.exs fix one, and in production runtime.exs takes
  `TOKEN_SIGNING_SECRET` or derives one from `SECRET_KEY_BASE`.
  """
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        LumenViae.Accounts.Admin,
        _opts,
        _context
      ) do
    Application.fetch_env(:lumen_viae, :token_signing_secret)
  end
end
