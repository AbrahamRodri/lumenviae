defmodule LumenViae.Services.GeolocationTest do
  use ExUnit.Case, async: true

  alias LumenViae.Services.Geolocation

  describe "anonymize/1" do
    test "drops the last octet of an IPv4 address" do
      assert Geolocation.anonymize("203.0.113.7") == "203.0.113.0"
      assert Geolocation.anonymize("8.8.8.8") == "8.8.8.0"
    end

    test "keeps only the routing prefix of an IPv6 address" do
      assert Geolocation.anonymize("2001:db8:85a3:8d3:1319:8a2e:370:7348") == "2001:db8:85a3::"
    end

    test "answers nil for anything that is not an address" do
      assert Geolocation.anonymize(nil) == nil
      assert Geolocation.anonymize("not an address") == nil
      assert Geolocation.anonymize(12_345) == nil
    end
  end

  describe "routable?/1" do
    test "public addresses are routable" do
      assert Geolocation.routable?("203.0.113.7")
      assert Geolocation.routable?("8.8.8.8")
      assert Geolocation.routable?("2001:db8::1")
    end

    test "loopback, private and link-local ranges are not" do
      for ip <- [
            "127.0.0.1",
            "10.1.2.3",
            "192.168.1.1",
            "172.16.0.1",
            "172.31.255.254",
            "169.254.1.1",
            "::1",
            "fe80::1"
          ] do
        refute Geolocation.routable?(ip), "expected #{ip} not to be routable"
      end
    end

    test "a carrier-grade NAT address places nobody" do
      refute Geolocation.routable?("100.64.0.1")
    end

    test "172.32 is public, despite sitting next to the private block" do
      assert Geolocation.routable?("172.32.0.1")
    end

    test "nonsense is not routable" do
      refute Geolocation.routable?("not an address")
      refute Geolocation.routable?(nil)
    end
  end

  describe "locate/1" do
    test "answers nil without a request when lookups are switched off" do
      # Off in the test environment, which is what makes this an assertion
      # about configuration rather than about the network.
      assert Geolocation.locate("8.8.8.8") == nil
    end

    test "answers nil for a private address" do
      assert Geolocation.locate("127.0.0.1") == nil
    end
  end
end
