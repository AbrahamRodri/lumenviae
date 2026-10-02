defmodule LumenViaeWeb.Plugs.RequireAdminTest do
  @moduledoc """
  The development skip signs in the seeded dev admin - a real account, so
  the console's policies still run with an actor - and only that.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Accounts

  test "without the skip, the console sends a visitor to the login page", %{conn: conn} do
    put_env(:lumen_viae, :skip_admin_auth, false)
    assert conn |> get("/admin") |> redirected_to() == "/admin/login"
  end

  test "the skip signs in the dev admin and the console mounts as them", %{conn: conn} do
    put_env(:lumen_viae, :skip_admin_auth, true)
    admin_fixture(Accounts.dev_admin_email())

    conn = get(conn, "/admin")
    assert html_response(conn, 200)
    assert is_binary(get_session(conn, "admin_token"))

    {:ok, view, _html} = conn |> recycle() |> live("/admin")
    assert render(view) =~ "Dashboard"
  end

  test "the skip with no dev admin seeded still refuses", %{conn: conn} do
    put_env(:lumen_viae, :skip_admin_auth, true)
    assert conn |> get("/admin") |> redirected_to() == "/admin/login"
  end

  test "no config file but dev.exs sets the skip, and runtime.exs never reads it" do
    for file <- ["config/config.exs", "config/prod.exs", "config/runtime.exs", "config/test.exs"] do
      refute File.read!(file) =~ "skip_admin_auth", "#{file} mentions :skip_admin_auth"
    end

    assert File.read!("config/dev.exs") =~ "config :lumen_viae, :skip_admin_auth, true"
  end
end
