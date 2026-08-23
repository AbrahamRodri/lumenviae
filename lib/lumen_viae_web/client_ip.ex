defmodule LumenViaeWeb.ClientIP do
  @moduledoc """
  Finds the address a request actually came from.

  ## Why `X-Forwarded-For` is not read at all

  It was, once, and it was wrong. The reasoning was that Fly appends the
  client's address to the header, so the *rightmost* entry would be the
  real one and the leftmost - which is caller-supplied and therefore
  spoofable - could be ignored.

  Fly appends its own address. The first Rosary this recorded in production
  came from `2a09:8280:1::`, which is `FLYIO-V6-ANYCAST`, and the lookup
  duly reported the location of Fly's proxy. Every completion would have
  agreed with every other one, and the figures would have looked plausible
  and meant nothing.

  The lesson is not "use the other end of the header". It is that the
  correct entry in `X-Forwarded-For` depends on how many proxies sit in
  front of the application and what each of them does, which is knowledge
  this module has no reliable way to hold. So it reads the two things that
  are unambiguous:

    * `Fly-Client-IP`, which Fly sets itself and overwrites on the way in,
      so a caller cannot forge it; and
    * the socket peer, which is correct when nothing is in front of the
      application at all.

  **If this app ever moves off Fly, or gains a CDN in front of it, this
  module needs revisiting** - `Fly-Client-IP` would stop arriving and every
  request would be attributed to the peer, which behind a proxy is the
  proxy.
  """

  @header "fly-client-ip"

  @doc """
  The client address for a `Plug.Conn`, as a string, or `nil`.
  """
  def from_conn(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, @header) do
      [value | _] -> presence(value) || peer_address(conn.remote_ip)
      [] -> peer_address(conn.remote_ip)
    end
  end

  @doc """
  The client address a LiveView was given, which arrives through the
  session rather than through `connect_info`.

  `connect_info`'s `:x_headers` collects only headers beginning with `x-`,
  so `Fly-Client-IP` never reaches a socket. Rather than fall back to a
  header whose ordering cannot be trusted, `LumenViaeWeb.Plugs.PutClientIP`
  reads the authoritative one during the ordinary HTTP request and puts it
  in the session, which is signed and so cannot be edited by the caller.
  """
  def from_session(%{"client_ip" => ip}) when is_binary(ip), do: presence(ip)
  def from_session(_session), do: nil

  defp peer_address(address) when is_tuple(address) do
    address |> :inet.ntoa() |> to_string()
  end

  defp peer_address(_other), do: nil

  defp presence(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp presence(_other), do: nil
end
