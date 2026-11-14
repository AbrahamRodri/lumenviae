defmodule LumenViae.Office.DivinumOfficiumTest do
  @moduledoc """
  What the engine client decides on its own: how to connect to the base
  URL it was given, and what it refuses to read (a redirect, a body past
  its cap). Everything else it does is exercised through
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

  describe "what it refuses to read" do
    test "a redirect is not followed" do
      calls = :counters.new(1, [])

      Req.Test.stub(DivinumOfficium, fn conn ->
        :counters.add(calls, 1, 1)

        conn
        |> Plug.Conn.put_resp_header("location", "https://elsewhere.example/")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert {:error, {:upstream_status, 302}} =
               DivinumOfficium.fetch_hour(
                 ~D[2026-11-14],
                 "Laudes",
                 "Rubrics 1960 - 1960",
                 "English"
               )

      assert :counters.get(calls, 1) == 1
    end

    test "a body past the cap is dropped" do
      big = String.duplicate("a", DivinumOfficium.max_body_bytes() + 1)
      Req.Test.stub(DivinumOfficium, &Plug.Conn.send_resp(&1, 200, big))

      assert {:error, :too_large} =
               DivinumOfficium.fetch_hour(
                 ~D[2026-11-14],
                 "Laudes",
                 "Rubrics 1960 - 1960",
                 "English"
               )
    end

    test "a page under the cap is read whole" do
      Req.Test.stub(DivinumOfficium, &Plug.Conn.send_resp(&1, 200, "<html>Laudes</html>"))

      assert {:ok, "<html>Laudes</html>"} =
               DivinumOfficium.fetch_hour(
                 ~D[2026-11-14],
                 "Laudes",
                 "Rubrics 1960 - 1960",
                 "English"
               )
    end
  end
end
