defmodule LumenViae.Accounts.AdminPasswordHashTest do
  @moduledoc """
  The password hash is AshAuthentication's alone: an admin reading admins,
  as AshAdmin's data browser does, does not get it, while signing in
  (which needs it) still works.
  """
  use LumenViae.DataCase, async: true

  alias LumenViae.Accounts
  alias LumenViae.Accounts.Admin
  alias LumenViae.Test.Admins

  test "an admin reading an admin sees the email but not the password hash" do
    stored = Admins.admin_fixture()

    {:ok, read} =
      Accounts.get_admin_by_email(to_string(stored.email), actor: Admins.admin())

    assert read.id == stored.id
    assert to_string(read.email) == to_string(stored.email)
    assert %Ash.NotLoaded{} = read.hashed_password
  end

  test "signing in still reads the hash" do
    stored = Admins.admin_fixture()
    strategy = AshAuthentication.Info.strategy!(Admin, :password)

    assert {:ok, %Admin{}} =
             AshAuthentication.Strategy.action(strategy, :sign_in, %{
               email: to_string(stored.email),
               password: Admins.password()
             })

    assert {:error, _wrong} =
             AshAuthentication.Strategy.action(strategy, :sign_in, %{
               email: to_string(stored.email),
               password: "not the password"
             })
  end
end
