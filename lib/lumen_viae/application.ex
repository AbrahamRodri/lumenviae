defmodule LumenViae.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # One log line as each job starts, finishes, fails or is cancelled, with
    # its worker, queue, attempt and timings, so `fly logs` says what the
    # queues did without opening Oban Web. Jobs only: the plugins' events
    # (the pruner every five minutes, the cron every minute) would bury them.
    # Arguments are logged too, which is safe because nothing goes in them
    # that could not be stored on a row (docs/ARCHITECTURE.md).
    Oban.Telemetry.attach_default_logger(level: :info, events: [:job], encode: false)

    children = [
      LumenViaeWeb.Telemetry,
      LumenViae.Repo,
      {DNSCluster, query: Application.get_env(:lumen_viae, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LumenViae.PubSub},
      # Owns the counters behind every rate limit (AshRateLimiter's backend).
      {LumenViae.Hammer, clean_period: :timer.minutes(10)},
      # Owns the IP-to-place cache.
      LumenViae.Services.Geolocation,
      # Owns the parsed Divine Office cache.
      LumenViae.Office.Cache,
      # AshAuthentication's own processes: chiefly the expunger, which
      # deletes expired rows from `admin_tokens` (revocations included)
      # every twelve hours. Without it that table only grows.
      {AshAuthentication.Supervisor, otp_app: :lumen_viae},
      # Background jobs, with every resource's AshOban triggers added to
      # the configured queues. After the Repo, which it needs, and before
      # the endpoint, so a request can enqueue as soon as it can be served.
      {Oban, oban_config()},
      # Start to serve requests, typically the last entry
      LumenViaeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LumenViae.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp oban_config do
    AshOban.config(
      Application.fetch_env!(:lumen_viae, :ash_domains),
      Application.fetch_env!(:lumen_viae, Oban)
    )
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LumenViaeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
