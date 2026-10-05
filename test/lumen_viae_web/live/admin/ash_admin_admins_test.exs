defmodule LumenViaeWeb.Live.Admin.AshAdminAdminsTest do
  @moduledoc """
  AshAdmin's data browser lists admins without their password hash, which
  is left out of every read that is not AshAuthentication's own.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LumenViae.Test.EnvStub, only: [put_env: 3]

  setup do
    put_env(:lumen_viae, :skip_admin_auth, false)
    :ok
  end

  setup :sign_in_admin

  test "the admins table renders, with no hash in it", %{conn: conn, admin: admin} do
    {:ok, _view, html} =
      live(conn, "/admin/data?domain=Accounts&resource=Admin&action_type=read")

    assert html =~ to_string(admin.email)
    refute html =~ "$2b$"
  end
end
