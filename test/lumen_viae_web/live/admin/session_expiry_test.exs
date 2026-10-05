defmodule LumenViaeWeb.Live.Admin.SessionExpiryTest do
  @moduledoc """
  A console tab left open ends when its token does, as a fresh request
  would, rather than acting on past the token's expiry.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViaeWeb.UserAuth

  setup do
    put_env(:lumen_viae, :skip_admin_auth, false)
    :ok
  end

  setup :sign_in_admin

  test "a signed-in token expires about seven days out", %{conn: conn} do
    token = conn |> get("/admin") |> get_session("admin_token")
    ms = UserAuth.ms_until_expiry(token)

    seven_days = :timer.hours(24 * 7)
    assert ms > seven_days - :timer.minutes(5) and ms <= seven_days
  end

  test "an unreadable or missing token schedules nothing" do
    assert UserAuth.ms_until_expiry(nil) == nil
    assert UserAuth.ms_until_expiry("not a jwt") == nil
  end

  test "when the token expires, the open page goes to the login", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin")

    send(view.pid, :admin_session_expired)

    assert_redirect(view, "/admin/login")
  end

  test "the expunger that deletes expired tokens is running" do
    assert Enum.any?(
             Supervisor.which_children(LumenViae.Supervisor),
             &match?({AshAuthentication.Supervisor, pid, _, _} when is_pid(pid), &1)
           )
  end
end
