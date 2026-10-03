defmodule LumenViaeWeb.Plugs.GuardCompletions do
  @moduledoc """
  Stands in front of `POST /api/completions`, the one write the public API
  exposes, and turns a crawler away.

  Every other API route is a read of content that is public anyway, so the
  worst an automated caller does there is cost a little bandwidth. This
  route writes a row that a dashboard is then read as fact, which makes it
  worth guarding properly: an afternoon with a loop running is an afternoon
  of figures that say a great deal happened and mean nothing.

  **A crawler is turned away** on its user agent. This is not security -
  an agent string is whatever the caller says it is - and it is not trying
  to be. It is hygiene, and it catches the honest majority: the crawlers
  and preview fetchers that announce themselves correctly and would
  otherwise POST their way through the route while indexing the app.

  ## The rate limit is not here

  It is what still holds when the agent string is a lie, and it is on the
  action, not in front of it (see `LumenViae.Limits`), so
  the REST route, the prayer page and GraphQL spend one budget per address
  by construction. A refusal from it reaches the client through
  `LumenViaeWeb.API.FallbackController` as the same `429 rate_limited` this
  plug used to send. A crawler is refused here, before the action, so it
  never spends any of an address's budget.

  ## What is deliberately not here

  No shared secret between the app and this route. It would have to ship
  inside the app binary, where anybody willing to run `strings` on it can
  read it, so it would stop nothing that the rate limit does not already
  stop while breaking every copy of the app already installed the moment it
  was ever rotated.
  """

  import Plug.Conn

  alias LumenViaeWeb.BotDetection

  def init(opts), do: opts

  def call(conn, _opts) do
    case check(BotDetection.user_agent(conn)) do
      :ok -> conn
      {:refuse, status, code, message} -> refuse(conn, status, code, message)
    end
  end

  @doc """
  The crawler check, for a caller with this user agent. Shared with the
  GraphQL `recordCompletion` mutation (`LumenViaeWeb.Graphql.GuardCompletions`),
  which turns a crawler away the same way.

  Returns `:ok` or `{:refuse, http_status, code, message}`.
  """
  def check(user_agent) do
    if BotDetection.bot?(user_agent) do
      {:refuse, :forbidden, "automated_client", "Automated clients cannot record completions"}
    else
      :ok
    end
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
