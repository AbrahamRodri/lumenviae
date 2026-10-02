defmodule LumenViaeWeb.AshAdminActor do
  @moduledoc """
  Gives AshAdmin at `/admin/data` the signed-in admin as its actor.

  AshAdmin's own plug lets whoever is using it pick any record as the actor
  from cookies, and runs unauthorized until told otherwise. Here the actor
  is always `current_admin`, which the console's `:require_admin` mount
  hook has already loaded and insisted on; authorization is on; and the
  picker is hidden (no actor resources), so the browser runs every action
  as exactly the admin who signed in.

  AshAdmin's sidebar also offers "Auth bypassed" and "clear actor", and
  both make it run every action with `authorize?: false`. That would undo
  the one rule an admin does not pass: making admins and setting passwords
  are refused to every actor (`LumenViae.Accounts.Admin`), so that a
  hijacked session cannot plant an admin. So `on_mount(:lock_authorization,
  ...)`, attached in the router, drops those two events before AshAdmin
  sees them, and authorization stays on for the life of the page.

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

  @locked_events ["toggle_authorizing", "clear_actor"]

  @doc false
  def on_mount(:lock_authorization, _params, _session, socket) do
    {:cont,
     Phoenix.LiveView.attach_hook(socket, :lock_authorization, :handle_event, fn
       event, _params, socket when event in @locked_events -> {:halt, socket}
       _event, _params, socket -> {:cont, socket}
     end)}
  end
end
