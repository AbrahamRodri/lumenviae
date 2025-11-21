defmodule LumenViaeWeb.UserAuth do
  @moduledoc """
  LiveView lifecycle hooks for checking user authentication status.
  """
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    is_admin = Map.get(session, "admin_authenticated", false)
    {:cont, assign(socket, :is_admin, is_admin)}
  end
end
