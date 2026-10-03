defmodule LumenViae.Limits do
  @moduledoc """
  The completion limit, and what a refusal says: how many, over how long,
  under what key.

  The limit is enforced by the actions it protects, through AshRateLimiter
  (`LumenViae.Rosary.Completion.RateLimit`), so every way into them - REST,
  the prayer page, GraphQL - shares one budget by construction. This module
  only says what the budget is.

  `:completions_per_hour` (20) is Rosaries recorded per address per hour. A
  family sharing a connection, or a parish behind one router, stays well
  under it; a script does not. It is read from the application environment
  at the moment it is applied, not compiled in, because AshRateLimiter's own
  DSL takes literals and the test suite needs to lower the limit for one test
  and put it back. The default is the production value. The test environment
  sets it very high, because the whole suite connects from one address; the
  tests that exercise the limit set their own.

  Sign-in is throttled separately, in front of the form
  (`LumenViaeWeb.Plugs.ThrottleSignIn`); see why there.

  ## Keys

  Each limit has its own prefix, because the counters are shared and a key
  is the only thing keeping two limits apart (see `LumenViae.Hammer`). The
  completion key is the full address, not the truncated prefix that is
  stored: telling neighbours apart is the whole job, and truncating
  destroys exactly that.
  """

  alias AshRateLimiter.LimitExceeded

  @completions_per_hour 20

  @doc """
  The completion limit as AshRateLimiter options, for a caller at `ip`.
  """
  def completion(ip) when is_binary(ip) do
    [
      limit: Application.get_env(:lumen_viae, :completions_per_hour, @completions_per_hour),
      per: :timer.hours(1),
      key: "completion:" <> ip
    ]
  end

  @doc """
  What a refusal says, in the words each surface has always used.
  """
  def message(%LimitExceeded{key: "completion:" <> _}),
    do: "Too many completions from this address"

  def message(%LimitExceeded{}), do: "Too many requests"

  @doc """
  The `AshRateLimiter.LimitExceeded` inside an error an action returned, or
  `nil` when the error is about something else.

  AshRateLimiter's error is class `:forbidden`, so it arrives wrapped in an
  `Ash.Error.Forbidden`.
  """
  def exceeded(%LimitExceeded{} = error), do: error

  def exceeded(%{errors: errors}) when is_list(errors), do: Enum.find_value(errors, &exceeded/1)

  def exceeded(_other), do: nil
end

defimpl AshGraphql.Error, for: AshRateLimiter.LimitExceeded do
  # The fixed text from `LumenViae.Limits`, not Exception.message/1, which
  # says only "Rate limit exceeded" and, once the error has passed through an
  # action, is prefixed with "Bread Crumbs" that name the server's modules.
  # The code is the one the REST API and the guard that preceded this have
  # always used.
  def to_error(error) do
    message = LumenViae.Limits.message(error)

    %{
      message: message,
      short_message: message,
      code: "rate_limited",
      vars: %{},
      fields: []
    }
  end
end
