defmodule LumenViaeWeb.ClientIPCloudflareTest do
  @moduledoc """
  `LumenViaeWeb.ClientIP.Cloudflare.edge?/1` against the ranges compiled in
  from `priv/cloudflare/`.
  """
  use ExUnit.Case, async: true

  alias LumenViaeWeb.ClientIP.Cloudflare

  test "the published ranges are compiled in, both families" do
    families = Cloudflare.ranges() |> Enum.map(&elem(&1, 0)) |> Enum.frequencies()
    assert families[4] >= 10 and families[8] >= 5
  end

  test "an address inside a range is Cloudflare's, up to its last address" do
    # 172.64.0.0/13 runs to 172.71.255.255
    assert Cloudflare.edge?("172.64.0.0")
    assert Cloudflare.edge?("172.71.255.255")
    refute Cloudflare.edge?("172.72.0.0")
    refute Cloudflare.edge?("172.63.255.255")
  end

  test "IPv6, and IPv4 carried in IPv6" do
    assert Cloudflare.edge?("2606:4700:10::ac43:1")
    refute Cloudflare.edge?("2001:db8::1")
    assert Cloudflare.edge?("::ffff:172.70.1.2")
    assert Cloudflare.edge?({172, 70, 1, 2})
  end

  test "documentation addresses, private ones and garbage are not" do
    for address <- ["198.51.100.9", "10.0.0.2", "127.0.0.1", "not an ip", "", nil] do
      refute Cloudflare.edge?(address), inspect(address)
    end
  end
end
