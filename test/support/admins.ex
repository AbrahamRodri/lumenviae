defmodule LumenViae.Test.Admins do
  @moduledoc """
  Admins for the suite.

  `admin/0` is an actor, not an account: the policies only ask whether the
  actor is an `%Admin{}`, so a test that sets data up through the domain,
  or exercises the console's reads, acts as one without touching the
  database or bcrypt. `admin_fixture/1` is a real account, for the tests
  that sign in. `sign_in_admin/1` is a `setup` callback for a ConnCase that
  needs the console.

  Public reads and the completion write are deliberately called without an
  actor in the tests that cover them, as the site and the APIs call them.
  """

  alias LumenViae.Accounts
  alias LumenViae.Accounts.Admin

  @password "correct horse battery staple"

  def password, do: @password

  @doc "An admin actor that exists only in memory."
  def admin do
    %Admin{id: "00000000-0000-0000-0000-00000000ad31", email: "actor@lumenviae.test"}
  end

  @doc "A stored admin account whose password is `password/0`."
  def admin_fixture(email \\ nil) do
    email = email || "admin#{System.unique_integer([:positive])}@lumenviae.test"
    {:ok, admin} = Accounts.create_admin(email, @password, authorize?: false)
    admin
  end

  @doc """
  Signs `admin` in on `conn` the way the sign-in form does: through the
  password strategy, so the session holds a real, stored token.
  """
  def log_in_admin(conn, admin \\ admin_fixture()) do
    strategy = AshAuthentication.Info.strategy!(Admin, :password)

    {:ok, signed_in} =
      AshAuthentication.Strategy.action(strategy, :sign_in, %{
        email: to_string(admin.email),
        password: @password
      })

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(signed_in)
  end

  @doc "`setup :sign_in_admin` - a conn with an admin signed in, and the admin."
  def sign_in_admin(%{conn: conn}) do
    admin = admin_fixture()
    %{conn: log_in_admin(conn, admin), admin: admin}
  end
end
