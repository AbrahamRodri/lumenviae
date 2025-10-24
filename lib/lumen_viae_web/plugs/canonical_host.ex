defmodule LumenViaeWeb.Plugs.CanonicalHost do
  @moduledoc """
  A Plug to redirect all requests to the canonical host.

  This ensures that all traffic is redirected to www.lumenviae.org,
  regardless of whether they access via lumenviae.org or lumenviae.fly.dev.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  @canonical_host "www.lumenviae.org"

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only perform redirect in production
    if prod_environment?() do
      do_redirect(conn)
    else
      conn
    end
  end

  defp prod_environment? do
    # Check if we're in production by looking at the configured host
    # In development/test, host will be "localhost"
    case Application.get_env(:lumen_viae, LumenViaeWeb.Endpoint) do
      nil -> false
      config ->
        host = get_in(config, [:url, :host])
        host != nil and host != "localhost"
    end
  end

  defp do_redirect(conn) do
    host = conn.host

    if host != @canonical_host do
      # Build the canonical URL
      canonical_url = "https://#{@canonical_host}#{conn.request_path}"

      # Add query string if present
      canonical_url =
        case conn.query_string do
          "" -> canonical_url
          query_string -> "#{canonical_url}?#{query_string}"
        end

      conn
      |> put_status(:moved_permanently)
      |> redirect(external: canonical_url)
      |> halt()
    else
      conn
    end
  end
end
