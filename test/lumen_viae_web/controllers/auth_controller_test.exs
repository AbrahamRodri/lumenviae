defmodule LumenViaeWeb.AuthControllerTest do
  @moduledoc """
  Signing in to the console with an email and a password, and signing out.

  The form on /admin/login posts to the password strategy's route; these
  tests post there exactly as the browser does.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LumenViae.Test.EnvStub, only: [put_env: 3]

  @sign_in "/admin/auth/admin/password/sign_in"

  setup do
    put_env(:lumen_viae, :skip_admin_auth, false)
    :ok
  end

  defp sign_in(conn, email, password) do
    post(conn, @sign_in, %{"admin" => %{"email" => email, "password" => password}})
  end

  test "the login page asks for an email and a password and posts to the strategy", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/login")

    assert html =~ ~s(action="#{@sign_in}")
    assert html =~ ~s(name="admin[email]")
    assert html =~ ~s(name="admin[password]")
    assert html =~ "admin-input"
    refute html =~ "Admin password"
  end

  test "the right password signs in and opens the console", %{conn: conn} do
    admin = admin_fixture()

    conn = sign_in(conn, to_string(admin.email), password())
    assert redirected_to(conn) == "/admin"
    assert is_binary(get_session(conn, "admin_token"))

    conn = conn |> recycle() |> get("/admin")
    assert html_response(conn, 200) =~ "Dashboard"
  end

  test "the email is matched without regard to case", %{conn: conn} do
    admin = admin_fixture("Mixed.Case#{System.unique_integer([:positive])}@LumenViae.test")

    conn = sign_in(conn, String.downcase(to_string(admin.email)), password())
    assert redirected_to(conn) == "/admin"
  end

  test "a wrong password is refused without saying which half was wrong", %{conn: conn} do
    admin = admin_fixture()

    conn = sign_in(conn, to_string(admin.email), "not the password at all")
    assert redirected_to(conn) == "/admin/login"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Incorrect email or password"
    refute get_session(conn, "admin_token")

    unknown = sign_in(build_conn(), "nobody@lumenviae.test", password())
    assert redirected_to(unknown) == "/admin/login"
    assert Phoenix.Flash.get(unknown.assigns.flash, :error) == "Incorrect email or password"
  end

  test "the sign-in form is CSRF-checked like every other form", %{conn: conn} do
    admin = admin_fixture()

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> init_test_session(%{})
      |> put_private(:plug_skip_csrf_protection, false)
      |> sign_in(to_string(admin.email), password())
    end
  end

  test "signing out ends the session and revokes its token", %{conn: conn} do
    conn = log_in_admin(conn)
    assert conn |> get("/admin") |> html_response(200)

    signed_out = delete(conn, "/admin/session")
    assert redirected_to(signed_out) == "/"

    # The old cookie, replayed after sign-out, opens nothing.
    assert conn |> get("/admin") |> redirected_to() == "/admin/login"
  end

  test "an admin who is already signed in is sent past the login page", %{conn: conn} do
    conn = log_in_admin(conn)
    assert {:error, {:redirect, %{to: "/admin"}}} = live(conn, "/admin/login")
  end
end
