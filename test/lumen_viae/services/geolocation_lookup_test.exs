defmodule LumenViae.Services.GeolocationLookupTest do
  @moduledoc """
  The lookup itself, against a stubbed provider.

  Not async: it switches geolocation on through application config, which is
  global, and every other test in the suite relies on it being off.
  """
  use ExUnit.Case, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Services.Geolocation

  defp enable(provider) do
    put_env([
      {:lumen_viae, :geolocation,
       enabled: true, provider: provider, req_options: [plug: {Req.Test, Geolocation}]}
    ])
  end

  # A fresh address per test, because answers are cached by address for a
  # day and the cache outlives a test.
  defp an_address do
    n = System.unique_integer([:positive])
    "203.0.#{rem(n, 250)}.#{rem(div(n, 250), 250)}"
  end

  describe "ipapi.co" do
    setup do
      enable(:ipapi_co)
      :ok
    end

    test "reads a place out of a successful answer" do
      Req.Test.stub(Geolocation, fn conn ->
        Req.Test.json(conn, %{
          "city" => "Dallas",
          "region" => "Texas",
          "country_name" => "United States",
          "country_code" => "US"
        })
      end)

      assert Geolocation.locate(an_address()) == %{
               city: "Dallas",
               region: "Texas",
               country: "United States",
               country_code: "US"
             }
    end

    test "answers nil when the provider says it cannot place the address" do
      Req.Test.stub(Geolocation, fn conn ->
        Req.Test.json(conn, %{"error" => true, "reason" => "Reserved IP Address"})
      end)

      assert Geolocation.locate(an_address()) == nil
    end

    # Its daily quota running out comes back as a 200 with an error body.
    test "a rate limit is transient, not an answer" do
      Req.Test.stub(Geolocation, fn conn ->
        Req.Test.json(conn, %{"error" => true, "reason" => "RateLimited"})
      end)

      assert Geolocation.locate(an_address()) == {:error, :transient}
    end

    test "a 429 or a 5xx is transient rather than raising" do
      for status <- [429, 503] do
        Req.Test.stub(Geolocation, fn conn ->
          conn |> Plug.Conn.put_status(status) |> Req.Test.json(%{})
        end)

        assert Geolocation.locate(an_address()) == {:error, :transient}
      end
    end

    test "a failed connection is transient rather than raising" do
      Req.Test.stub(Geolocation, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert Geolocation.locate(an_address()) == {:error, :transient}
    end

    test "a transient failure is not cached: the next lookup asks again" do
      test_pid = self()
      ip = an_address()

      Req.Test.stub(Geolocation, fn conn ->
        send(test_pid, :asked)
        conn |> Plug.Conn.put_status(503) |> Req.Test.json(%{})
      end)

      assert Geolocation.locate(ip) == {:error, :transient}

      Req.Test.stub(Geolocation, fn conn ->
        send(test_pid, :asked)
        Req.Test.json(conn, %{"country_name" => "Ireland", "country_code" => "IE"})
      end)

      assert %{country_code: "IE"} = Geolocation.locate(ip)
      assert_received :asked
      assert_received :asked
    end

    test "a place with no city still yields its country" do
      Req.Test.stub(Geolocation, fn conn ->
        Req.Test.json(conn, %{
          "city" => nil,
          "region" => nil,
          "country_name" => "Ireland",
          "country_code" => "IE"
        })
      end)

      assert %{city: nil, country_code: "IE"} = Geolocation.locate(an_address())
    end
  end

  describe "ip-api.com" do
    setup do
      enable(:ip_api_com)
      :ok
    end

    test "reads that provider's differently named fields" do
      Req.Test.stub(Geolocation, fn conn ->
        Req.Test.json(conn, %{
          "status" => "success",
          "city" => "Manila",
          "regionName" => "Metro Manila",
          "country" => "Philippines",
          "countryCode" => "PH"
        })
      end)

      assert Geolocation.locate(an_address()) == %{
               city: "Manila",
               region: "Metro Manila",
               country: "Philippines",
               country_code: "PH"
             }
    end

    test "answers nil on that provider's failure shape" do
      Req.Test.stub(Geolocation, fn conn ->
        Req.Test.json(conn, %{"status" => "fail", "message" => "reserved range"})
      end)

      assert Geolocation.locate(an_address()) == nil
    end
  end

  describe "the cache" do
    setup do
      enable(:ipapi_co)
      :ok
    end

    test "asks the provider once per address, however many completions arrive" do
      test_pid = self()

      Req.Test.stub(Geolocation, fn conn ->
        send(test_pid, :asked)

        Req.Test.json(conn, %{
          "city" => "Warsaw",
          "region" => "Mazovia",
          "country_name" => "Poland",
          "country_code" => "PL"
        })
      end)

      ip = an_address()

      for _ <- 1..5 do
        assert %{country_code: "PL"} = Geolocation.locate(ip)
      end

      assert_received :asked
      refute_received :asked
    end

    test "remembers a failure too, so an unplaceable address is not re-asked" do
      test_pid = self()

      Req.Test.stub(Geolocation, fn conn ->
        send(test_pid, :asked)
        Req.Test.json(conn, %{"error" => true})
      end)

      ip = an_address()

      assert Geolocation.locate(ip) == nil
      assert Geolocation.locate(ip) == nil

      assert_received :asked
      refute_received :asked
    end
  end
end
