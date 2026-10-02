defmodule LumenViae.Accounts.ReleaseAdminTest do
  @moduledoc """
  The production shell's way to make the first admin and replace a
  forgotten password: a generated password, printed once.
  """
  use LumenViae.DataCase, async: false

  import ExUnit.CaptureIO

  alias LumenViae.Accounts.Admin
  alias LumenViae.Release

  defp signs_in?(email, password) do
    strategy = AshAuthentication.Info.strategy!(Admin, :password)

    match?(
      {:ok, _admin},
      AshAuthentication.Strategy.action(strategy, :sign_in, %{email: email, password: password})
    )
  end

  defp email, do: "owner#{System.unique_integer([:positive])}@lumenviae.test"

  test "create_admin/1 makes an admin with a generated password and prints it once" do
    email = email()

    output =
      capture_io(fn ->
        assert {:ok, password} = Release.create_admin(email)
        send(self(), {:password, password})
      end)

    assert_received {:password, password}
    assert String.length(password) >= 32
    assert output =~ "Created admin #{email}"
    assert length(String.split(output, password)) == 2
    assert signs_in?(email, password)
  end

  test "create_admin/1 refuses an address that is already an admin" do
    email = email()
    capture_io(fn -> {:ok, _} = Release.create_admin(email) end)

    output = capture_io(fn -> assert {:error, _summary} = Release.create_admin(email) end)
    assert output =~ "ERROR"
  end

  test "reset_admin_password/1 replaces the password and signs the admin out everywhere" do
    admin = admin_fixture()
    email = to_string(admin.email)
    session = build_conn_session(admin)

    output =
      capture_io(fn ->
        assert {:ok, password} = Release.reset_admin_password(email)
        send(self(), {:password, password})
      end)

    assert_received {:password, new_password}
    assert output =~ new_password
    assert signs_in?(email, new_password)
    refute signs_in?(email, password())

    socket = %Phoenix.LiveView.Socket{
      endpoint: LumenViaeWeb.Endpoint,
      assigns: %{__changed__: %{}, flash: %{}}
    }

    assert {:halt, _} = LumenViaeWeb.UserAuth.on_mount(:require_admin, %{}, session, socket)
  end

  test "reset_admin_password/1 says so for an address that is not an admin" do
    output =
      capture_io(fn ->
        assert {:error, :not_found} = Release.reset_admin_password("nobody@lumenviae.test")
      end)

    assert output =~ "no admin"
  end

  defp build_conn_session(admin) do
    Phoenix.ConnTest.build_conn() |> log_in_admin(admin) |> Plug.Conn.get_session()
  end
end
