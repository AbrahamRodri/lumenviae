defmodule LumenViae.Test.Admins do
  @moduledoc """
  Admins for the suite.

  `admin/0` is an actor, not an account to sign in with: the policies only
  ask whether the actor is an `%Admin{}`, so a test that sets data up
  through the domain, or exercises the console's reads, acts as one without
  bcrypt. Its row is stored once, before the suite, by `store_admin!/0`,
  because a content write records its actor on the version row and the
  version's `admin_id` is a foreign key. `admin_fixture/1` is a real account, for the tests
  that sign in. `sign_in_admin/1` is a `setup` callback for a ConnCase that
  needs the console.

  Public reads and the completion write are deliberately called without an
  actor in the tests that cover them, as the site and the APIs call them.
  """

  alias LumenViae.Accounts
  alias LumenViae.Accounts.Admin

  @password "correct horse battery staple"

  def password, do: @password

  @admin_id "00000000-0000-0000-0000-00000000ad31"
  @admin_email "actor@lumenviae.test"

  @doc "The suite's admin actor. Its row is stored by `store_admin!/0`."
  def admin do
    %Admin{id: @admin_id, email: @admin_email}
  end

  @doc """
  Stores `admin/0`'s row if it is not there yet. Run once from
  `test_helper.exs`, outside the sandbox, so every test sees it. Written
  with the Repo because the create action takes no id, and the id has to
  be the fixed one the in-memory actor carries. The password hash is
  never checked: nothing signs in as this admin.
  """
  def store_admin! do
    now = NaiveDateTime.utc_now()

    LumenViae.Repo.insert_all(
      "admins",
      [
        %{
          id: Ecto.UUID.dump!(@admin_id),
          email: @admin_email,
          hashed_password: "not a hash: this admin never signs in",
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: :nothing
    )
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
    |> Plug.Conn.put_session(:live_socket_id, LumenViaeWeb.AdminSockets.id(signed_in))
  end

  @doc "`setup :sign_in_admin` - a conn with an admin signed in, and the admin."
  def sign_in_admin(%{conn: conn}) do
    admin = admin_fixture()
    %{conn: log_in_admin(conn, admin), admin: admin}
  end
end
