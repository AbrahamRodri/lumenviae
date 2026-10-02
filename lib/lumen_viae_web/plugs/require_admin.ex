defmodule LumenViaeWeb.Plugs.RequireAdmin do
  @moduledoc """
  Requires a signed-in admin for the `/admin` routes, redirecting to the
  login page when there is not one.

  `:load_from_session` in the browser pipeline has already put the admin in
  `current_admin`, having checked the session's token is genuine, unexpired
  and not revoked; this plug only refuses a request without one.

  In development the login is skipped: `config/dev.exs` sets
  `:skip_admin_auth`, and this plug signs in the dev admin that
  `priv/repo/seeds.exs` creates instead of turning the check off, so the
  console runs its policies with a real actor and everything downstream -
  the LiveView mount hook, the logout form, `@is_admin` - behaves exactly
  as in production. The skip is compiled only in dev and test (a release
  is built in prod, where the clause below does not exist), and only dev.exs
  sets the flag.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(%{assigns: %{current_admin: %{}}} = conn, _opts), do: conn

  def call(conn, _opts) do
    case skipped_sign_in(conn) do
      {:ok, conn} ->
        conn

      :error ->
        conn
        |> put_flash(:error, "You must be signed in to access this page")
        |> redirect(to: "/admin/login")
        |> halt()
    end
  end

  if Mix.env() in [:dev, :test] do
    alias LumenViae.Accounts

    defp skipped_sign_in(conn) do
      with true <- Application.get_env(:lumen_viae, :skip_admin_auth, false),
           # Reading an admin by email is AshAuthentication's job; this is the
           # one other caller, it exists only outside a release, and there is
           # no actor yet - signing one in is the point.
           {:ok, admin} <-
             Accounts.get_admin_by_email(Accounts.dev_admin_email(), authorize?: false),
           {:ok, token, _claims} <- AshAuthentication.Jwt.token_for_user(admin) do
        admin = Ash.Resource.put_metadata(admin, :token, token)

        {:ok,
         conn
         |> AshAuthentication.Plug.Helpers.store_in_session(admin)
         |> put_session(:live_socket_id, LumenViaeWeb.AdminSockets.id(admin))
         |> assign(:current_admin, admin)}
      else
        _not_skipped -> :error
      end
    end
  else
    defp skipped_sign_in(_conn), do: :error
  end
end
