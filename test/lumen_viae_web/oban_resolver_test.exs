defmodule LumenViaeWeb.ObanResolverTest do
  @moduledoc """
  Oban Web keeps the resolved user in its LiveView session, signed into
  the page but not encrypted, so the resolver must hand it the admin's id
  and email and never the record behind them.
  """
  use ExUnit.Case, async: true

  alias LumenViaeWeb.ObanResolver

  test "hands Oban Web the admin's id and email, and nothing else" do
    admin = %LumenViae.Accounts.Admin{
      id: "00000000-0000-0000-0000-00000000ad31",
      email: "actor@lumenviae.test",
      hashed_password: "$2b$12$not-for-the-page"
    }

    conn = Plug.Conn.assign(%Plug.Conn{}, :current_admin, admin)

    assert ObanResolver.resolve_user(conn) == %{
             id: "00000000-0000-0000-0000-00000000ad31",
             email: "actor@lumenviae.test"
           }

    refute inspect(ObanResolver.resolve_user(conn)) =~ "hashed_password"
  end

  test "nobody signed in resolves to nobody" do
    assert ObanResolver.resolve_user(%Plug.Conn{}) == nil
  end
end
