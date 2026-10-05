ExUnit.start()

# Before the sandbox: one committed row every test's admin actor points at.
LumenViae.Test.Admins.store_admin!()

Ecto.Adapters.SQL.Sandbox.mode(LumenViae.Repo, :manual)
