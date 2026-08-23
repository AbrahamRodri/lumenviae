defmodule LumenViaeWeb.Plugs.GuardCompletions do
  @moduledoc """
  Stands in front of `POST /api/completions`, the one write the public API
  exposes.

  Every other API route is a read of content that is public anyway, so the
  worst an automated caller does there is cost a little bandwidth. This
  route writes a row that a dashboard is then read as fact, which makes it
  worth guarding properly: an afternoon with a loop running is an afternoon
  of figures that say a great deal happened and mean nothing.

  Two checks, for two different problems.

  **A crawler is turned away** on its user agent. This is not security -
  an agent string is whatever the caller says it is - and it is not trying
  to be. It is hygiene, and it catches the honest majority: the crawlers
  and preview fetchers that announce themselves correctly and would
  otherwise POST their way through the route while indexing the app.

  **Everyone is rate limited**, by address, and this is the part that holds
  when the agent string is a lie. A caller pretending to be Safari is still
  one address, and one address gets `@completions_per_hour` Rosaries an
  hour.

  ## What is deliberately not here

  No shared secret between the app and this route. It would have to ship
  inside the app binary, where anybody willing to run `strings` on it can
  read it, so it would stop nothing that the rate limit does not already
  stop while breaking every copy of the app already installed the moment it
  was ever rotated.
  """

  import Plug.Conn

  alias LumenViae.RateLimit
  alias LumenViaeWeb.BotDetection
  alias LumenViaeWeb.ClientIP

  # Configurable so the test suite is not sharing one budget across every
  # test that happens to post a completion - they all arrive from 127.0.0.1
  # and would otherwise spend each other's allowance.
  @default_completions_per_hour 20

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      BotDetection.bot?(BotDetection.user_agent(conn)) ->
        refuse(
          conn,
          :forbidden,
          "automated_client",
          "Automated clients cannot record completions"
        )

      rate_limited?(conn) ->
        refuse(conn, :too_many_requests, "rate_limited", "Too many completions from this address")

      true ->
        conn
    end
  end

  defp rate_limited?(conn) do
    case ClientIP.from_conn(conn) do
      nil -> false
      ip -> RateLimit.check("completion:" <> ip, completions_per_hour(), :timer.hours(1)) != :ok
    end
  end

  defp completions_per_hour do
    Application.get_env(:lumen_viae, :completions_per_hour, @default_completions_per_hour)
  end

  # The body matches the API's error envelope so a client has one shape to
  # parse rather than two.
  defp refuse(conn, status, code, message) do
    conn
    |> put_status(status)
    |> Phoenix.Controller.put_view(json: LumenViaeWeb.API.ErrorJSON)
    |> Phoenix.Controller.render(:error, code: code, message: message, details: nil)
    |> halt()
  end
end
