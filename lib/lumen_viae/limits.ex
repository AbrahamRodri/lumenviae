defmodule LumenViae.Limits do
  @moduledoc """
  The completion limit, and what a refusal says: how many, over how long,
  under what key.

  The limit is enforced by the actions it protects, through AshRateLimiter
  (`LumenViae.Rosary.Completion.RateLimit`), so every way into them - REST,
  the prayer page, GraphQL, `/api/v2` - shares one budget by construction. This module
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
  is the only thing keeping two limits apart (see `LumenViae.Hammer`).

  The completion key is the caller's address, not the truncated prefix that
  is stored: telling neighbours apart is the whole job, and truncating to a
  /24 destroys exactly that. `address/1` says which address.

  ## Which address

  An IPv4 address is one subscriber's, so it is the key whole. An IPv6
  address is not: a subscriber is handed a whole /64 (a home connection, a
  phone), can use any address in it, and with privacy extensions does,
  changing the last 64 bits as often as it likes. Keyed on the full
  address, such a caller gets a fresh budget on every request. So an IPv6
  address is keyed on its /64, which is the smallest network that is one
  caller's. Two callers in one /64 - a campus, say - share a budget, which is
  the price and is small against 20 an hour. An IPv4-mapped IPv6 address
  (`::ffff:203.0.113.9`) is the IPv4 address it carries.

  ## How long is left

  The counters are fixed windows aligned to the clock, so how long is left in
  one is a function of the clock and the window alone (`retry_after/1`),
  which is what a refusal's `Retry-After` header says.
  """

  import Bitwise

  alias AshRateLimiter.LimitExceeded

  @completions_per_hour 20
  @completion_window :timer.hours(1)

  @doc """
  The completion limit as AshRateLimiter options, for a caller at `ip`.
  """
  def completion(ip) when is_binary(ip) do
    [
      limit: Application.get_env(:lumen_viae, :completions_per_hour, @completions_per_hour),
      per: @completion_window,
      key: "completion:" <> address(ip)
    ]
  end

  @admin_confirmations 10
  @admin_confirmation_window :timer.minutes(15)

  @doc """
  How often one admin may try their own password to add an admin or replace
  a password from the console (`LumenViae.Accounts.Admin.ConfirmActorPassword`):
  10 attempts in 15 minutes per machine, right or wrong. The counters are
  per machine, like every limit here, and production runs two, so the real
  ceiling is about 20 in 15 minutes. Keyed on the admin, not the address,
  because the thing being guessed is that admin's password.
  """
  def admin_confirmation(admin_id) when is_binary(admin_id) do
    [
      limit: @admin_confirmations,
      per: @admin_confirmation_window,
      key: "admin-confirmation:" <> admin_id
    ]
  end

  @doc """
  The window, in milliseconds, of the limit called `name`. Only the
  completion limit has one that a response needs to say.
  """
  def window(:completion), do: @completion_window

  @doc """
  The address a limit counts a caller by: the whole address for IPv4, and the
  /64 for IPv6, written as the network (`2001:db8:1:2::/64`) so it can never
  be mistaken for an address. See "Which address" above.

  Written however the caller's proxy wrote it - upper case, `::` or not -
  an IPv6 address means the same network, so every spelling of it is one
  key. A string that is not an address is its own key, unchanged: nothing
  here may fail a request over what a header said.
  """
  def address(ip) when is_binary(ip) do
    case ip |> String.to_charlist() |> :inet.parse_address() do
      {:ok, {_, _, _, _} = v4} ->
        v4 |> :inet.ntoa() |> to_string()

      # IPv4-mapped (::ffff:a.b.c.d): the IPv4 address it carries.
      {:ok, {0, 0, 0, 0, 0, 0xFFFF, hi, lo}} ->
        {hi >>> 8, hi &&& 0xFF, lo >>> 8, lo &&& 0xFF} |> :inet.ntoa() |> to_string()

      {:ok, {a, b, c, d, _, _, _, _}} ->
        to_string(:inet.ntoa({a, b, c, d, 0, 0, 0, 0})) <> "/64"

      {:error, _} ->
        ip
    end
  end

  @doc """
  Whole seconds left in the current window of `window_ms`, and at least one:
  the `Retry-After` of a refusal. Hammer's fixed window ends at the next
  multiple of its size on the system clock, so this is that clock and
  nothing else.
  """
  def retry_after(window_ms) when is_integer(window_ms) and window_ms > 0 do
    left_ms = window_ms - rem(System.system_time(:millisecond), window_ms)
    max(div(left_ms + 999, 1000), 1)
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

defimpl AshJsonApi.ToJsonApiError, for: AshRateLimiter.LimitExceeded do
  # /api/v2's answer: REST's 429 and code, as a JSON:API error, with the
  # same fixed text. Without this AshJsonApi would answer a generic 403,
  # since the error's class is :forbidden.
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: 429,
      code: "rate_limited",
      title: "RateLimited",
      detail: LumenViae.Limits.message(error),
      meta: %{}
    }
  end
end
