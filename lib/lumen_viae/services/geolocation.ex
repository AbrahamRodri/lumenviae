defmodule LumenViae.Services.Geolocation do
  @moduledoc """
  Service for fetching geolocation data from IP addresses.
  Uses ip-api.com free tier (no API key required, 45 requests/minute limit).
  """

  require Logger

  @doc """
  Fetches location data for a given IP address.

  Returns a map with :city, :region, :country, :country_code keys on success.
  Returns nil if the request fails or IP is invalid.

  ## Examples

      iex> get_location("8.8.8.8")
      %{city: "Mountain View", region: "California", country: "United States", country_code: "US"}

      iex> get_location("127.0.0.1")
      nil
  """
  def get_location(nil), do: nil
  def get_location(""), do: nil

  def get_location(ip_address) when is_binary(ip_address) do
    # Skip localhost and private IPs
    if private_or_localhost?(ip_address) do
      Logger.debug("Skipping geolocation for private/localhost IP: #{ip_address}")
      nil
    else
      fetch_from_api(ip_address)
    end
  end

  defp fetch_from_api(ip_address) do
    # Ensure inets and ssl applications are started (needed in production)
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    url = "http://ip-api.com/json/#{ip_address}?fields=status,city,regionName,country,countryCode"
    Logger.info("Fetching geolocation for IP: #{ip_address} from #{url}")

    case :httpc.request(:get, {String.to_charlist(url), []}, [{:timeout, 10000}], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        result = parse_response(List.to_string(body))
        Logger.info("Geolocation success for #{ip_address}: #{inspect(result)}")
        result

      {:ok, {{_, status_code, _}, _headers, body}} ->
        Logger.warning("Geolocation API returned status #{status_code} for IP #{ip_address}, body: #{List.to_string(body)}")
        nil

      {:error, reason} ->
        Logger.error("Geolocation API request failed for IP #{ip_address}: #{inspect(reason)}")
        nil
    end
  end

  defp parse_response(body) do
    case Jason.decode(body) do
      {:ok, %{"status" => "success", "city" => city, "regionName" => region,
              "country" => country, "countryCode" => country_code}} ->
        %{
          city: city,
          region: region,
          country: country,
          country_code: country_code
        }

      {:ok, %{"status" => "fail"}} ->
        nil

      {:error, _reason} ->
        nil
    end
  end

  defp private_or_localhost?(ip) do
    # Check for localhost and private IP ranges
    ip in ["127.0.0.1", "::1", "localhost"] or
    String.starts_with?(ip, "192.168.") or
    String.starts_with?(ip, "10.") or
    String.starts_with?(ip, "172.16.") or
    String.starts_with?(ip, "172.17.") or
    String.starts_with?(ip, "172.18.") or
    String.starts_with?(ip, "172.19.") or
    String.starts_with?(ip, "172.20.") or
    String.starts_with?(ip, "172.21.") or
    String.starts_with?(ip, "172.22.") or
    String.starts_with?(ip, "172.23.") or
    String.starts_with?(ip, "172.24.") or
    String.starts_with?(ip, "172.25.") or
    String.starts_with?(ip, "172.26.") or
    String.starts_with?(ip, "172.27.") or
    String.starts_with?(ip, "172.28.") or
    String.starts_with?(ip, "172.29.") or
    String.starts_with?(ip, "172.30.") or
    String.starts_with?(ip, "172.31.")
  end
end
