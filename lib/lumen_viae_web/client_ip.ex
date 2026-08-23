defmodule LumenViaeWeb.ClientIP do
  @moduledoc """
  Finds the address a request actually came from, and reduces it to
  something coarse enough to store.

  ## Why not just read `X-Forwarded-For` left to right

  The conventional reading - leftmost entry is the original client - is the
  wrong one behind a proxy, because the leftmost entry is whatever the
  caller typed. Anyone can open a terminal and send

      X-Forwarded-For: 8.8.8.8

  and Fly's proxy will *append* the real address rather than replace the
  header, leaving `8.8.8.8, 203.0.113.7`. Trusting the left of that hands
  every visitor a free hand in the analytics and a way around a per-address
  rate limit, which is the more expensive half.

  So the order here is: `Fly-Client-IP` first, which Fly sets itself and
  overwrites on the way in; then the *rightmost* `X-Forwarded-For` entry,
  which is the one the last proxy appended; and only then the socket peer,
  which is correct when nothing is in front of the application at all.

  `@trusted_hops` is 1 because exactly one proxy sits in front of this app
  in production. Putting a CDN in front of Fly would make it 2, and leaving
  it at 1 would then read the CDN's address as the visitor's.
  """

  @trusted_hops 1

  @doc """
  The client address for a `Plug.Conn`, as a string, or `nil` if there is
  nothing usable.
  """
  def from_conn(%Plug.Conn{} = conn) do
    fly_client_ip(&Plug.Conn.get_req_header(conn, &1)) ||
      forwarded_for(&Plug.Conn.get_req_header(conn, &1)) ||
      peer_address(conn.remote_ip)
  end

  @doc """
  The client address for a LiveView socket.

  Reads the same headers, which reach a LiveView only when the endpoint
  asks for `:x_headers` and `:peer_data` in its socket `connect_info`.
  Returns `nil` on the disconnected mount, where there is no connect info
  to read - which is harmless here, because a completion is only ever
  written from a connected socket.
  """
  def from_connect_info(x_headers, peer_data) do
    headers = x_headers || []
    get = fn name -> for {^name, value} <- headers, do: value end

    fly_client_ip(get) || forwarded_for(get) || peer_address(peer_data)
  end

  defp fly_client_ip(get) do
    case get.("fly-client-ip") do
      [value | _] -> presence(value)
      [] -> nil
    end
  end

  defp forwarded_for(get) do
    case get.("x-forwarded-for") do
      [] ->
        nil

      values ->
        values
        |> Enum.join(",")
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.reverse()
        |> Enum.drop(@trusted_hops - 1)
        |> List.first()
        |> presence()
    end
  end

  defp peer_address(%{address: address}), do: peer_address(address)
  defp peer_address(address) when is_tuple(address), do: address |> :inet.ntoa() |> to_string()
  defp peer_address(_other), do: nil

  defp presence(nil), do: nil

  defp presence(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
