defmodule LumenViaeWeb.ClientIP.Cloudflare do
  @moduledoc """
  Whether an address is one of Cloudflare's edge servers, from the ranges
  Cloudflare publishes at https://www.cloudflare.com/ips/, kept in
  `priv/cloudflare/ips-v4.txt` and `ips-v6.txt` and compiled in.
  `mix lumen_viae.cloudflare_ips` refreshes the two files.

  `LumenViaeWeb.ClientIP` asks it before believing `CF-Connecting-IP`: that
  header is only Cloudflare's word when Cloudflare is the one who sent the
  request.
  """
  import Bitwise

  @files ~w(ips-v4.txt ips-v6.txt)
  @paths Enum.map(@files, &Path.join([__DIR__, "../../../priv/cloudflare", &1]))

  for path <- @paths, do: @external_resource(path)

  @ranges @paths
          |> Enum.flat_map(&(&1 |> File.read!() |> String.split("\n", trim: true)))
          |> Enum.map(fn cidr ->
            [address, bits] = cidr |> String.trim() |> String.split("/")
            {:ok, ip} = address |> String.to_charlist() |> :inet.parse_address()
            {tuple_size(ip), ip, String.to_integer(bits)}
          end)

  @doc """
  The ranges, as `{family_size, address, prefix_length}`: 4 for IPv4, 8 for
  IPv6.
  """
  def ranges, do: @ranges

  @doc """
  True when `address` (a string such as `"172.70.1.2"`, or an `:inet`
  tuple) lies in one of Cloudflare's ranges. Anything unparseable is not.
  """
  def edge?(address) when is_binary(address) do
    case address |> String.trim() |> String.to_charlist() |> :inet.parse_address() do
      {:ok, ip} -> edge?(ip)
      {:error, _} -> false
    end
  end

  def edge?(ip) when is_tuple(ip) do
    ip = unmap(ip)

    Enum.any?(@ranges, fn {size, net, bits} ->
      tuple_size(ip) == size and prefix(ip, bits) == prefix(net, bits)
    end)
  end

  def edge?(_other), do: false

  # An IPv4 address carried in IPv6 (::ffff:a.b.c.d) is that IPv4 address.
  defp unmap({0, 0, 0, 0, 0, 0xFFFF, hi, lo}), do: {hi >>> 8, hi &&& 255, lo >>> 8, lo &&& 255}
  defp unmap(ip), do: ip

  defp prefix(ip, bits) do
    width = if tuple_size(ip) == 4, do: 8, else: 16
    total = tuple_size(ip) * width

    value =
      ip |> Tuple.to_list() |> Enum.reduce(0, fn part, acc -> (acc <<< width) + part end)

    value >>> (total - bits)
  end
end
