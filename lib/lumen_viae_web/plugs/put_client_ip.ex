defmodule LumenViaeWeb.Plugs.PutClientIP do
  @moduledoc """
  Puts the caller's address in the session so a LiveView can read it.

  A LiveView cannot see `Fly-Client-IP`: `connect_info`'s `:x_headers`
  collects only headers beginning with `x-`, and the alternative -
  `X-Forwarded-For` - cannot be read without knowing the proxy layout, which
  is exactly the assumption that previously attributed every Rosary prayed
  on the website to Fly's own proxy in Chicago.

  So the authoritative header is read here, during the ordinary HTTP
  request where it does arrive, and carried to the socket in the session.
  The session is signed, so a caller cannot edit the value on its way back.

  The value is the caller's own address, which they already know, so putting
  it in their own cookie tells them nothing new. It is never stored in full:
  see `LumenViae.Services.Geolocation.anonymize/1`.
  """

  alias LumenViaeWeb.ClientIP

  def init(opts), do: opts

  def call(conn, _opts) do
    case ClientIP.from_conn(conn) do
      nil -> conn
      ip -> Plug.Conn.put_session(conn, :client_ip, ip)
    end
  end
end
