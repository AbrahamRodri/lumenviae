defmodule LumenViae.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LumenViaeWeb.Telemetry,
      LumenViae.Repo,
      {DNSCluster, query: Application.get_env(:lumen_viae, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LumenViae.PubSub},
      # Start a worker by calling: LumenViae.Worker.start_link(arg)
      # {LumenViae.Worker, arg},
      # Start to serve requests, typically the last entry
      LumenViaeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LumenViae.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LumenViaeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
