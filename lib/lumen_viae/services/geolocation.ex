defmodule LumenViae.Services.Geolocation do
  @moduledoc """
  Turns an IP address into a rough place: city, region, country.

  ## Configuration

      config :lumen_viae, :geolocation,
        enabled: true,
        provider: :ipapi_co,
        req_options: []

  `:enabled` is the switch. With it off - the default in dev and test -
  `locate/1` returns `nil` without making a request, so nobody's address
  leaves a laptop during development.

  ## Choosing a provider

  `:ipapi_co` is the default because it answers over HTTPS without an API
  key. `:ip_api_com` is more generous (45 requests a minute against 1,000 a
  day) but its free tier is **plaintext HTTP only**, which means every
  visitor's address crosses the open internet in the clear on its way to
  being looked up. For an app whose privacy policy is its selling point
  that is the wrong default, so it is available and not chosen.

  ## Caching

  Answers are cached by address for a day. Somebody praying a novena from
  the same sofa is one lookup rather than nine, which is what keeps a free
  tier viable and, more to the point, means their address is sent away
  once instead of nine times.

  Lookups are never made on the request path - see
  `LumenViae.Rosary.record_completion/2`, which writes the completion
  first and fills the place in afterwards. A slow third party must not be
  able to hold up the end of somebody's Rosary.
  """

  use GenServer

  require Logger

  @table :lumen_viae_geolocation_cache
  @ttl_ms :timer.hours(24)
  @sweep_interval_ms :timer.hours(1)

  @receive_timeout_ms 5_000
  @connect_timeout_ms 3_000

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  The place an address is in, or `nil` when that cannot be established.

  `nil` is an ordinary answer, not an error: the lookup is disabled, the
  address is private, the provider is down, or it simply does not know.
  Every caller has to be able to carry on without a place.
  """
  def locate(nil), do: nil
  def locate(""), do: nil

  def locate(ip) when is_binary(ip) do
    cond do
      not enabled?() -> nil
      not routable?(ip) -> nil
      true -> cached_or_fetch(ip)
    end
  end

  def locate(_other), do: nil

  defp cached_or_fetch(ip) do
    case fetch_cached(ip) do
      {:ok, location} ->
        location

      :miss ->
        location = fetch(ip)
        put_cached(ip, location)
        location
    end
  end

  defp fetch_cached(ip) do
    case :ets.lookup(@table, ip) do
      [{^ip, location, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at, do: {:ok, location}, else: :miss

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  # A failed lookup is cached too. Without that, an address the provider
  # cannot place is re-asked on every completion from it, which is exactly
  # the traffic the cache exists to prevent.
  defp put_cached(ip, location) do
    expires_at = System.monotonic_time(:millisecond) + @ttl_ms
    :ets.insert(@table, {ip, location, expires_at})
    :ok
  rescue
    ArgumentError -> :ok
  end

  defp fetch(ip) do
    {url, parser} = provider(ip)

    options =
      [
        receive_timeout: @receive_timeout_ms,
        connect_options: [timeout: @connect_timeout_ms],
        retry: false
      ]
      |> Keyword.merge(config(:req_options, []))

    case Req.get(url, options) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        parser.(body)

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Geolocation provider answered #{status}")
        nil

      {:error, exception} ->
        Logger.warning("Geolocation lookup failed: #{Exception.message(exception)}")
        nil
    end
  rescue
    # A place on an analytics row is never worth raising over.
    exception ->
      Logger.warning("Geolocation lookup raised: #{Exception.message(exception)}")
      nil
  end

  defp provider(ip) do
    case config(:provider, :ipapi_co) do
      :ipapi_co -> {"https://ipapi.co/#{ip}/json/", &parse_ipapi_co/1}
      :ip_api_com -> {"http://ip-api.com/json/#{ip}", &parse_ip_api_com/1}
    end
  end

  defp parse_ipapi_co(%{"error" => true}), do: nil

  defp parse_ipapi_co(%{"country_code" => code} = body) when is_binary(code) do
    %{
      city: presence(body["city"]),
      region: presence(body["region"]),
      country: presence(body["country_name"]),
      country_code: code
    }
  end

  defp parse_ipapi_co(_other), do: nil

  defp parse_ip_api_com(%{"status" => "success", "countryCode" => code} = body) do
    %{
      city: presence(body["city"]),
      region: presence(body["regionName"]),
      country: presence(body["country"]),
      country_code: code
    }
  end

  defp parse_ip_api_com(_other), do: nil

  defp presence(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp presence(_other), do: nil

  @doc """
  Whether an address is one a public provider could say anything about.

  Loopback, private and link-local ranges are every address seen in
  development and every address seen if the proxy headers are ever read
  wrongly, and asking a third party to place one wastes a lookup to be told
  no.
  """
  def routable?(ip) when is_binary(ip) do
    case :inet.parse_address(String.to_charlist(ip)) do
      {:ok, {127, _, _, _}} -> false
      {:ok, {10, _, _, _}} -> false
      {:ok, {192, 168, _, _}} -> false
      {:ok, {169, 254, _, _}} -> false
      {:ok, {172, second, _, _}} when second in 16..31 -> false
      # Carrier-grade NAT: real traffic, but the address belongs to the
      # carrier's inside network and places nobody.
      {:ok, {100, second, _, _}} when second in 64..127 -> false
      {:ok, {0, _, _, _}} -> false
      {:ok, {_, _, _, _}} -> true
      {:ok, {0, 0, 0, 0, 0, 0, 0, 1}} -> false
      # fc00::/7 unique local, fe80::/10 link local
      {:ok, {first, _, _, _, _, _, _, _}} when first in 0xFC00..0xFDFF -> false
      {:ok, {first, _, _, _, _, _, _, _}} when first in 0xFE80..0xFEBF -> false
      {:ok, _ipv6} -> true
      {:error, :einval} -> false
    end
  end

  def routable?(_other), do: false

  @doc """
  Truncates an address to a network prefix: the last octet of an IPv4
  address, and everything below the routing prefix of an IPv6 one.

      iex> LumenViae.Services.Geolocation.anonymize("203.0.113.7")
      "203.0.113.0"

  This is what gets stored. It survives the only two questions the stored
  value is ever asked - are these two completions from roughly the same
  place, and what did the lookup say - while dropping the part that
  identifies a household. The full address is used in memory, for the
  lookup and for rate limiting, and is never written down.
  """
  def anonymize(nil), do: nil

  def anonymize(ip) when is_binary(ip) do
    case :inet.parse_address(String.to_charlist(ip)) do
      {:ok, {a, b, c, _d}} ->
        "#{a}.#{b}.#{c}.0"

      {:ok, {a, b, c, _, _, _, _, _}} ->
        {a, b, c, 0, 0, 0, 0, 0} |> :inet.ntoa() |> to_string()

      {:error, :einval} ->
        nil
    end
  end

  def anonymize(_other), do: nil

  @doc """
  Whether lookups are switched on at all. Callers use this to skip
  scheduling background work that would immediately do nothing.
  """
  def enabled?, do: config(:enabled, false)

  defp config(key, default) do
    :lumen_viae
    |> Application.get_env(:geolocation, [])
    |> Keyword.get(key, default)
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)
end
