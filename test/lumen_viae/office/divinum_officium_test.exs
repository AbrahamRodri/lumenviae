defmodule LumenViae.Office.DivinumOfficiumTest do
  @moduledoc """
  The one thing the engine client decides on its own: how to connect to
  the base URL it was given. Everything else it does is exercised through
  `LumenViae.Office` against the Req.Test stub.
  """

  use ExUnit.Case, async: true

  alias LumenViae.Office.DivinumOfficium

  describe "transport_options/1" do
    test "a Fly private name is connected over IPv6, which is all it resolves to" do
      assert DivinumOfficium.transport_options("http://lumenviae-office.flycast") ==
               [transport_opts: [inet6: true]]

      assert DivinumOfficium.transport_options("http://lumenviae-office.internal:8080") ==
               [transport_opts: [inet6: true]]
    end

    test "the public site and a local engine keep the default" do
      assert DivinumOfficium.transport_options("https://www.divinumofficium.com") == []
      assert DivinumOfficium.transport_options("http://localhost:8080") == []
    end
  end
end
