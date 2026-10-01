defmodule LumenViaeWeb.Graphql.PutRequestContext do
  @moduledoc """
  Puts what the server knows about a GraphQL request, and the client must
  not be allowed to say, into the Ash context every action receives: the
  caller's address (`LumenViaeWeb.ClientIP`, so `Fly-Client-IP` and the
  peer, never `X-Forwarded-For`) and its user agent.

  The completion mutation reads both. They come from the connection, never
  from the query's arguments, so a client cannot claim another address to
  dodge the rate limit or plant one in the analytics.

  Runs before `AshGraphql.Plug`, which hands this context to every action.
  """
  @behaviour Plug

  alias LumenViaeWeb.BotDetection
  alias LumenViaeWeb.ClientIP

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    Ash.PlugHelpers.set_context(conn, %{
      client_ip: ClientIP.from_conn(conn),
      user_agent: BotDetection.user_agent(conn)
    })
  end
end
