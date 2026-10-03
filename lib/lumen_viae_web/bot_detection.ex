defmodule LumenViaeWeb.BotDetection do
  @moduledoc """
  Decides whether a request came from an automated client.

  Used to keep crawlers out of the completion figures. It is one layer of
  two and the softer one: an agent string is whatever the caller says it
  is, so this catches the honest majority and the rate limit on the completion actions
  (see `LumenViae.Limits`) catches the rest. Nothing here should be read as a
  security boundary.

  Whether an agent is automated is `LumenViae.BotDetection.bot?/1`, below
  the web layer so that the completion action can ask it too; this module
  delegates to it and reads the agent off a connection or a socket.
  """

  @doc """
  Whether a user agent string belongs to an automated client. See
  `LumenViae.BotDetection.bot?/1`.
  """
  defdelegate bot?(user_agent), to: LumenViae.BotDetection

  @doc """
  The user agent on a `Plug.Conn`, or `nil`.
  """
  def user_agent(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [value | _] -> value
      [] -> nil
    end
  end

  @doc """
  The user agent from a LiveView socket's `connect_info`.
  """
  def user_agent_from_connect_info(%{user_agent: user_agent}), do: user_agent
  def user_agent_from_connect_info(_other), do: nil
end
