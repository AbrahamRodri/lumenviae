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

    * the one header the proxy in front sets itself and overwrites on the
      way in, so a caller cannot forge it: `Fly-Client-IP` on Fly, the
      default; and
    * the socket peer, which is correct when nothing is in front of the
      application at all.

  The header is a setting, `CLIENT_IP_HEADER` (`config :lumen_viae,
  :client_ip_header`), for a host other than Fly: on the VM in
  `deploy/vm/`, Caddy replaces `X-Real-IP` with the peer it saw, so the
  VM sets `CLIENT_IP_HEADER=x-real-ip`; behind Cloudflare's proxy it would
  be `cf-connecting-ip`. Name only a header the proxy overwrites: one it
  passes through is the caller's to choose. Without the right header every
  request is attributed to the peer, which behind a proxy is the proxy.

  Behind Cloudflare's proxy that address is Cloudflare's edge, and the
  visitor is in `CF-Connecting-IP`. With `CLIENT_IP_CLOUDFLARE=true` the
  header is read, but only when the address found above is one of
  Cloudflare's published ranges (`LumenViaeWeb.ClientIP.Cloudflare`), so a
  caller who reaches the origin directly cannot choose their own address.
  Off by default.

  ## Through the Fly pass-through

  Installed iPhones on 4.1 and earlier call `lumenviae.fly.dev`, which is
  now a proxy to `www.lumenviae.org` (`deploy/fly-proxy/`). Every such
  request reaches the VM from Fly's address. The proxy sends the caller's
  `Fly-Client-IP` as `X-LV-Client-IP`, beside `X-LV-Proxy-Secret`, a secret
  set on both sides (`FLY_PROXY_SECRET`, 32 characters or more). The first
  header is believed only when the second matches it; with the secret unset
  here, neither is read. Both are overwritten by the proxy on the way in, so
  a caller of `lumenviae.fly.dev` cannot choose them either.
  """

  alias LumenViaeWeb.ClientIP.Cloudflare

  @doc """
  The client address for a `Plug.Conn`, as a string, or `nil`.
  """
  def from_conn(%Plug.Conn{} = conn) do
    through_fly_proxy(conn) || direct(conn)
  end

  defp direct(conn) do
    seen =
      case Plug.Conn.get_req_header(conn, header()) do
        [value | _] -> presence(value) || peer_address(conn.remote_ip)
        [] -> peer_address(conn.remote_ip)
      end

    behind_cloudflare(conn, seen)
  end

  # The Fly pass-through's caller, only with the shared secret (moduledoc).
  defp through_fly_proxy(conn) do
    with secret when is_binary(secret) and byte_size(secret) >= 32 <-
           Application.get_env(:lumen_viae, :fly_proxy_secret),
         [given | _] <- Plug.Conn.get_req_header(conn, "x-lv-proxy-secret"),
         true <- Plug.Crypto.secure_compare(given, secret),
         [value | _] <- Plug.Conn.get_req_header(conn, "x-lv-client-ip"),
         address when is_binary(address) <- presence(value),
         {:ok, _ip} <- address |> String.to_charlist() |> :inet.parse_address() do
      address
    else
      _ -> nil
    end
  end

  # With `CLIENT_IP_CLOUDFLARE=true`, a request that reached us from one of
  # Cloudflare's edge servers is Cloudflare's, and `CF-Connecting-IP` is the
  # visitor it carried. From any other address that header is a caller's
  # claim and is ignored: on Fly the app can be reached directly, around
  # Cloudflare. Off by default, which leaves the address above untouched.
  defp behind_cloudflare(conn, seen) do
    with true <- Application.get_env(:lumen_viae, :client_ip_cloudflare, false),
         true <- Cloudflare.edge?(seen),
         [value | _] <- Plug.Conn.get_req_header(conn, "cf-connecting-ip"),
         visitor when is_binary(visitor) <- presence(value) do
      visitor
    else
      _ -> seen
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

  # Lowercase, as Plug holds request headers.
  defp header,
    do:
      :lumen_viae |> Application.get_env(:client_ip_header, "fly-client-ip") |> String.downcase()

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
