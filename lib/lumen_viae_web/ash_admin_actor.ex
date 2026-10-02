defmodule LumenViaeWeb.AshAdminActor do
  @moduledoc """
  Gives AshAdmin at `/admin/data` the signed-in admin as its actor.

  AshAdmin's own plug lets whoever is using it pick any record as the actor
  from cookies, and runs unauthorized until told otherwise. Here the actor
  is always `current_admin`, which the console's `:require_admin` mount
  hook has already loaded and insisted on; authorization is always on; and
  the picker is hidden (no actor resources), so the browser runs every
  action as exactly the admin who signed in.

  Set with `config :ash_admin, :actor_plug` in `config/config.exs`. AshAdmin
  reads that at compile time, so a change needs `mix deps.compile ash_admin`.
  """
  @behaviour AshAdmin.ActorPlug

  @impl true
  def actor_assigns(socket, _session) do
    [
      actor: socket.assigns[:current_admin],
      actor_domain: nil,
      actor_resources: [],
      actor_paused: false,
      actor_tenant: nil,
      authorizing: true,
      tenant: nil
    ]
  end

  @impl true
  def set_actor_session(conn), do: conn
end
