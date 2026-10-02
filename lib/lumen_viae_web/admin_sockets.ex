defmodule LumenViaeWeb.AdminSockets do
  @moduledoc """
  Names a signed-in admin's LiveView sockets, so they can be closed.

  A LiveView checks the session's token only when it mounts. Without this,
  a console tab already open would keep acting as its admin after that
  admin signs out, or after their password is reset and every token is
  revoked. So sign-in puts `:live_socket_id` in the session, which tags
  every socket the session opens, and sign-out and a password reset
  broadcast `"disconnect"` to the tag. A disconnected socket reconnects and
  mounts again, and the `:require_admin` hook in `LumenViaeWeb.UserAuth`
  refuses a revoked token there.

  The tag is per admin, not per session, so signing out on one device also
  interrupts that admin's tabs on another. Those tabs reconnect with their
  own still-valid tokens, so they are interrupted, not signed out.

  Production runs two clustered machines, so one broadcast reaches both.
  """

  @doc "The `:live_socket_id` for an admin's sockets."
  def id(%{id: id}), do: "admin_socket:" <> id

  @doc "Closes every LiveView socket the admin has open, on every machine."
  def disconnect(admin), do: LumenViaeWeb.Endpoint.broadcast(id(admin), "disconnect", %{})
end
