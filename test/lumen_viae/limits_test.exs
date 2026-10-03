defmodule LumenViae.LimitsTest do
  use ExUnit.Case, async: true

  alias AshRateLimiter.LimitExceeded
  alias LumenViae.Limits

  test "the completion resource spends its counters through the fail-open backend" do
    assert AshRateLimiter.Info.rate_limit_backend!(LumenViae.Rosary.Completion) ==
             LumenViae.Limits.Backend
  end

  describe "completion/1" do
    test "keys on the whole address, under its own prefix" do
      assert Limits.completion("203.0.113.9")[:key] == "completion:203.0.113.9"
      assert Limits.completion("2001:db8::1")[:key] == "completion:2001:db8::1"
    end

    test "is twenty an hour unless the environment says otherwise" do
      options = Limits.completion("203.0.113.9")

      assert options[:per] == :timer.hours(1)
      assert options[:limit] == Application.fetch_env!(:lumen_viae, :completions_per_hour)
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
