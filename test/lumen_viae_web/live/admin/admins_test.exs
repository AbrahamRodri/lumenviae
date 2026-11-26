defmodule LumenViaeWeb.Live.Admin.AdminsTest do
  @moduledoc """
  The Admins screen: the accounts, adding one, resetting another's
  password, changing your own. Each write wants the signed-in admin's own
  password, and a generated password is shown once.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Accounts

  setup %{conn: conn} do
    me = admin_fixture()
    {:ok, conn: log_in_admin(conn, me), me: me}
  end

  test "lists the admins and marks the one signed in", %{conn: conn, me: me} do
    other = admin_fixture()
    {:ok, _view, html} = live(conn, "/admin/admins")

    assert html =~ to_string(me.email)
    assert html =~ to_string(other.email)
    assert html =~ "You"
  end

  test "says when each admin last signed in, from their stored sessions", %{me: me} do
    other = admin_fixture()

    sign_ins = Accounts.last_sign_ins(actor: me)
    assert %DateTime{} = sign_ins[to_string(me.id)]
    refute Map.has_key?(sign_ins, to_string(other.id))

    assert LumenViaeWeb.Live.Admin.Admins.last_signed_in(sign_ins, other) ==
             "Not in the last week"

    # Anyone but an admin sees no sign-ins at all.
    assert Accounts.last_sign_ins([]) == %{}
  end

  test "an admin who signed out still shows when they last signed in", %{me: me} do
    other = admin_fixture()
    signed_in = log_in_admin(build_conn(), other)
    assert signed_in |> get("/admin") |> html_response(200)

    signed_out = delete(signed_in, "/admin/session")
    assert redirected_to(signed_out) == "/"

    sign_ins = Accounts.last_sign_ins(actor: me)
    assert %DateTime{} = sign_ins[to_string(other.id)]

    refute LumenViaeWeb.Live.Admin.Admins.last_signed_in(sign_ins, other) ==
             "Not in the last week"
  end

  test "adds an admin with your password and shows theirs once", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/admins")
    email = "added#{System.unique_integer([:positive])}@lumenviae.test"

    html =
      view
      |> form("#add-admin-form", admin: %{email: email, current_password: password()})
      |> render_submit()

    assert html =~ "Added #{email}"
    assert html =~ "shown this once"
    assert {:ok, _} = Accounts.get_admin_by_email(email, authorize?: false)
  end

  test "will not add an admin without your password", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/admins")
    email = "refused#{System.unique_integer([:positive])}@lumenviae.test"

    html =
      view
      |> form("#add-admin-form", admin: %{email: email, current_password: "a guess"})
      |> render_submit()

    assert html =~ "your password is incorrect"
    assert {:error, _} = Accounts.get_admin_by_email(email, authorize?: false)
  end

  test "resets another admin's password and closes their console tabs", %{conn: conn} do
    other = admin_fixture()
    LumenViaeWeb.Endpoint.subscribe(LumenViaeWeb.AdminSockets.id(other))
    {:ok, view, _html} = live(conn, "/admin/admins")

    view |> element(~s(button[phx-value-id="#{other.id}"])) |> render_click()

    html =
      view
      |> form("#reset-password-form", current_password: password())
      |> render_submit()

    assert html =~ "Replaced the password for #{other.email}"
    assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}
  end

  test "there is no reset button on your own row", %{conn: conn, me: me} do
    {:ok, view, _html} = live(conn, "/admin/admins")
    refute has_element?(view, ~s(button[phx-value-id="#{me.id}"]))
  end

  test "changing your own password sends you to sign in again", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/admins")
    new = "a brand new password here"

    assert {:error, {:redirect, %{to: "/admin/login"}}} =
             view
             |> form("#change-password-form",
               own: %{current_password: password(), password: new, password_confirmation: new}
             )
             |> render_submit()
  end
end
