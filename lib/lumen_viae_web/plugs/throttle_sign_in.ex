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

  Every attempt counts, successes included: `LumenViae.RateLimit` counts
  on each check. Five successful sign-ins to one account in 15 minutes is
  not a pattern anyone has. The counters are per machine, as rate_limit.ex
  explains, so with two machines the real ceiling is about double.

  Only `POST` to the strategy's sign-in route is counted; anything else
  under the auth routes passes straight through.
  """
  import Plug.Conn
  import Phoenix.Controller

  require Logger

  alias LumenViae.RateLimit
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
    RateLimit.check(prefix <> value, limit, @window_ms) != :ok
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
