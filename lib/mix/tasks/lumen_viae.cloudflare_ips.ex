defmodule Mix.Tasks.LumenViae.CloudflareIps do
  @shortdoc "Refreshes Cloudflare's published IP ranges in priv/cloudflare/"
  @moduledoc """
  Writes Cloudflare's current edge ranges, from https://www.cloudflare.com/ips-v4
  and https://www.cloudflare.com/ips-v6, into `priv/cloudflare/ips-v4.txt` and
  `ips-v6.txt`, which `LumenViaeWeb.ClientIP.Cloudflare` compiles in:

      mix lumen_viae.cloudflare_ips

  It refuses to write a list that does not parse, or that is empty, so a
  bad answer never leaves the app trusting nothing (or anything). Review
  the diff and commit it; the ranges change rarely.
  """
  use Mix.Task

  @lists [{"ips-v4", 4}, {"ips-v6", 8}]

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:req)

    for {name, size} <- @lists do
      body = Req.get!("https://www.cloudflare.com/" <> name, retry: false).body
      cidrs = body |> String.split("\n", trim: true) |> Enum.map(&String.trim/1)

      if cidrs == [] or not Enum.all?(cidrs, &cidr?(&1, size)) do
        Mix.raise("#{name}: not a list of ranges, nothing written:\n#{body}")
      end

      path = Path.join(["priv", "cloudflare", name <> ".txt"])
      File.write!(path, Enum.join(cidrs, "\n") <> "\n")
      Mix.shell().info("#{path}: #{length(cidrs)} ranges")
    end
  end

  defp cidr?(cidr, size) do
    with [address, bits] <- String.split(cidr, "/"),
         {bits, ""} <- Integer.parse(bits),
         {:ok, ip} <- address |> String.to_charlist() |> :inet.parse_address() do
      tuple_size(ip) == size and bits in 1..(size * if(size == 4, do: 8, else: 16))
    else
      _ -> false
    end
  end
end
