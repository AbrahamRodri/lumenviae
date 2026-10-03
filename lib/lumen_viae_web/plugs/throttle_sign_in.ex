defmodule LumenViaeWeb.Plugs.ThrottleSignIn do
  @moduledoc """
  Caps console sign-in attempts per address and per email, before the
  password is checked.

  Every attempt that reaches the password strategy runs bcrypt, known email
  or not, so an unthrottled form allows unlimited guessing and lets anyone
  spend the machine's CPU. This plug sits in front of the strategy and
  refuses an attempt once either budget is spent:

    * 10 attempts per address in 15 minutes (`:sign_in_per_ip`), which
      leaves an office or a VPN room for honest typos;
    * 5 attempts per email in 15 minutes (`:sign_in_per_email`), so a
      guesser rotating addresses still gets five tries at an account.

  The per-email limit means someone else's guessing can lock an admin out
  for up to 15 minutes. That is the price of the second limit, and it is
  the right trade for a console with a handful of accounts.

  Every attempt counts, successes included: the counter counts on each
  check. Five successful sign-ins to one account in 15 minutes is not a
  pattern anyone has. The counters are per machine, as `LumenViae.Hammer`
  explains, so with two machines the real ceiling is about double.

  ## Why this is a plug and not a limit on the sign-in action

  The completion limit moved onto its actions (AshRateLimiter, see
  `LumenViae.Limits`); this one did not, and the
  reason is the address. The per-email budget would move cleanly: the email
  is an argument of the strategy's `:sign_in_with_password` action. The
  per-address one cannot, because the action never sees a trustworthy
  address. `AshAuthentication.Plug.Dispatcher` replaces the connection's Ash
  context with its own on the way to the strategy, so nothing a plug puts
  there first (as `LumenViaeWeb.Graphql.PutRequestContext` does for GraphQL)
  survives, and the one address the dispatcher does supply is the socket
  peer, which behind Fly is Fly's proxy - the bug `LumenViaeWeb.ClientIP`
  describes. Keying on that would give every admin one shared budget.

  Splitting the two budgets between a plug and an action would be worse
  than either, so both stay here, in front of the strategy. A sign-in form
  has one surface, so there is no second place to forget it. If
  AshAuthentication ever lets a caller put context after its dispatcher, the
  throttle can move to the action as a preparation and this plug can go.

  Only `POST` to the strategy's sign-in route is counted; anything else
  under the auth routes passes straight through.
  """
  import Plug.Conn
  import Phoenix.Controller

  require Logger

  alias LumenViae.Limits.Backend
  alias LumenViae.Services.Geolocation
  alias LumenViaeWeb.ClientIP

  @sign_in_path "/admin/auth/admin/password/sign_in"
  @window_ms :timer.minutes(15)
  @default_per_ip 10
  @default_per_email 5

  def init(opts), do: opts

  def call(%Plug.Conn{method: "POST", request_path: @sign_in_path} = conn, opts) do
    ip = ClientIP.from_conn(conn)
    email = email(conn.params)

    ip_over? = over?("sign_in_ip:", ip, limit(opts, :per_ip))
    email_over? = over?("sign_in_email:", email, limit(opts, :per_email))

    if ip_over? or email_over? do
      Logger.warning("Console sign-in throttled from #{Geolocation.anonymize(ip) || "unknown"}")

      conn
      |> put_flash(:error, "Too many sign-in attempts. Try again in a few minutes.")
      |> redirect(to: "/admin/login")
      |> halt()
    else
      conn
    end
  end

  def call(conn, _opts), do: conn

  # Both budgets are spent on every attempt, not only until the first one
  # refuses, so a caller over one limit keeps counting against the other.
  defp over?(_prefix, nil, _limit), do: false

  defp over?(prefix, value, limit) do
    match?({:deny, _}, Backend.hit(prefix <> value, @window_ms, limit))
  end

  defp email(%{"admin" => %{"email" => email}}) when is_binary(email) do
    case email |> String.trim() |> String.downcase() do
      "" -> nil
      email -> email
    end
  end

  defp email(_params), do: nil

  # Options win over config so a test can set its own limits without
  # touching global state that other async tests read.
  defp limit(opts, :per_ip) do
    Keyword.get_lazy(opts, :per_ip, fn ->
      Application.get_env(:lumen_viae, :sign_in_per_ip, @default_per_ip)
    end)
  end

  defp limit(opts, :per_email) do
    Keyword.get_lazy(opts, :per_email, fn ->
      Application.get_env(:lumen_viae, :sign_in_per_email, @default_per_email)
    end)
  end
end
