defmodule LumenViae.LimitsTest do
  use ExUnit.Case, async: true

  alias AshRateLimiter.LimitExceeded
  alias LumenViae.Limits

  test "the completion resource spends its counters through the fail-open backend" do
    assert AshRateLimiter.Info.rate_limit_backend!(LumenViae.Rosary.Completion) ==
             LumenViae.Limits.Backend
  end

  describe "completion/1" do
    test "keys on the address, under its own prefix" do
      assert Limits.completion("203.0.113.9")[:key] == "completion:203.0.113.9"
      assert Limits.completion("2001:db8:1:2::7")[:key] == "completion:2001:db8:1:2::/64"
    end

    test "is twenty an hour unless the environment says otherwise" do
      options = Limits.completion("203.0.113.9")

      assert options[:per] == :timer.hours(1)
      assert options[:limit] == Application.fetch_env!(:lumen_viae, :completions_per_hour)
    end
  end

  describe "address/1" do
    test "is an IPv4 address whole, so two in one /24 are two callers" do
      assert Limits.address("203.0.113.9") == "203.0.113.9"
      refute Limits.address("203.0.113.9") == Limits.address("203.0.113.10")
    end

    test "is the /64 of an IPv6 address, written as a network" do
      assert Limits.address("2001:db8:1:2:3:4:5:6") == "2001:db8:1:2::/64"
      assert Limits.address("2001:db8:1:2::") == "2001:db8:1:2::/64"
    end

    test "is one network however the address is spelled" do
      spellings = ["2001:db8:a:b::1", "2001:0db8:000a:000b:0:0:0:1", "2001:DB8:A:B::FFFF"]

      assert spellings |> Enum.map(&Limits.address/1) |> Enum.uniq() == ["2001:db8:a:b::/64"]
    end

    test "distinguishes two /64s that differ only in the last bit of the fourth group" do
      refute Limits.address("2001:db8:a:b::1") == Limits.address("2001:db8:a:c::1")
    end

    test "reads an IPv4-mapped address as the IPv4 address it carries" do
      assert Limits.address("::ffff:203.0.113.9") == "203.0.113.9"
      assert Limits.address("::ffff:cb00:7109") == "203.0.113.9"
    end

    test "can never be mistaken for an address, so an IPv4 key and a network never meet" do
      assert String.ends_with?(Limits.address("2001:db8::1"), "/64")
      refute String.contains?(Limits.address("203.0.113.9"), "/")
    end

    test "leaves a string that is not an address as it was" do
      assert Limits.address("not an address") == "not an address"
      assert Limits.address("300.1.1.1") == "300.1.1.1"
      assert Limits.address("") == ""
    end
  end

  describe "retry_after/1" do
    test "is whole seconds, at least one and at most the window" do
      for window <- [1_000, 60_000, :timer.hours(1)] do
        assert Limits.retry_after(window) in 1..div(window, 1_000)
      end
    end

    test "is one second, not zero, in a window shorter than a second" do
      assert Limits.retry_after(500) == 1
    end
  end

  describe "exceeded/1" do
    test "finds the limit inside the Forbidden error an action returns" do
      limit = LimitExceeded.exception(key: "completion:203.0.113.9", limit: 20, per: 1)
      error = Ash.Error.Forbidden.exception(errors: [limit])

      assert Limits.exceeded(error) == limit
    end

    test "is nil for an error about anything else" do
      assert Limits.exceeded(Ash.Error.Forbidden.exception(errors: [])) == nil
      assert Limits.exceeded(Ash.Error.Invalid.exception(errors: [])) == nil
      assert Limits.exceeded(:not_found) == nil
    end
  end

  describe "message/1" do
    test "is the completion's own text, which every surface has always sent" do
      assert Limits.message(LimitExceeded.exception(key: "completion:203.0.113.9")) ==
               "Too many completions from this address"
    end
  end
end
