defmodule LumenViaeWeb.Live.Admin.Admins do
  @moduledoc """
  The console's accounts: who may sign in, adding an admin, replacing
  another admin's password, and changing your own.

  Every one of those writes asks for the signed-in admin's own password
  again (`LumenViae.Accounts.Admin.ConfirmActorPassword`), so a session
  cookie someone else got hold of cannot add an admin or lock one out. A
  generated password is shown once, in this page's state, and never
  stored in the clear; give it to its owner over a channel you trust.

  Resetting a password signs that admin out everywhere and closes their
  open console tabs. Changing your own does the same to you, here
  included, so the page sends you to sign in again.

  There is no removing an admin from here. Production has two, and a
  removal is rare enough to stay a shell job.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Accounts
  alias LumenViae.CentralTime
  alias LumenViaeWeb.AdminSockets

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admins")
     |> assign(:resetting, nil)
     |> assign(:revealed, nil)
     |> load()}
  end

  def handle_event("add_admin", %{"admin" => %{"email" => email} = params}, socket) do
    case Accounts.add_admin(email, params["current_password"], actor: me(socket)) do
      {:ok, admin, password} ->
        {:noreply,
         socket
         |> load()
         |> reveal(admin, password, "added")
         |> put_flash(:info, "Added #{admin.email}.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not add #{email}: " <> message(error))}
    end
  end

  def handle_event("start_reset", %{"id" => id}, socket) do
    {:noreply, assign(socket, :resetting, Enum.find(socket.assigns.admins, &(&1.id == id)))}
  end

  def handle_event("cancel_reset", _params, socket) do
    {:noreply, assign(socket, :resetting, nil)}
  end

  def handle_event("reset_password", %{"current_password" => current}, socket) do
    admin = socket.assigns.resetting

    case Accounts.reset_admin_password(admin, current, actor: me(socket)) do
      {:ok, admin, password} ->
        AdminSockets.disconnect(admin)

        {:noreply,
         socket
         |> assign(:resetting, nil)
         |> reveal(admin, password, "reset")
         |> put_flash(:info, "Replaced the password for #{admin.email} and signed them out.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not reset the password: " <> message(error))}
    end
  end

  def handle_event("change_password", %{"own" => params}, socket) do
    me = me(socket)

    case Accounts.change_own_password(
           me,
           params["password"],
           params["password_confirmation"],
           params["current_password"],
           actor: me
         ) do
      {:ok, me} ->
        AdminSockets.disconnect(me)

        {:noreply,
         socket
         |> put_flash(:info, "Password changed. Sign in with the new one.")
         |> redirect(to: "/admin/login")}

      {:error, error} ->
        {:noreply,
         put_flash(socket, :error, "Could not change your password: " <> message(error))}
    end
  end

  def handle_event("dismiss_password", _params, socket) do
    {:noreply, assign(socket, :revealed, nil)}
  end

  defp load(socket) do
    assign(socket, :admins, Accounts.list_admins!(actor: me(socket)))
  end

  defp me(socket), do: socket.assigns.current_admin

  defp reveal(socket, admin, password, verb) do
    assign(socket, :revealed, %{email: to_string(admin.email), password: password, verb: verb})
  end

  @doc "When an admin was added, in the reporting zone."
  def added(%{inserted_at: at}), do: CentralTime.format_short(at)

  @doc "Whether `admin` is the one signed in."
  def me?(admin, me), do: admin.id == me.id

  # What went wrong, in the words a person can act on. A refused attempt
  # limit gets its own sentence; otherwise each field error is named.
  defp message(error) do
    cond do
      LumenViae.Limits.exceeded(error) ->
        "too many tries at your password. Wait a quarter of an hour."

      match?(%Ash.Error.Forbidden{}, error) ->
        "not allowed."

      true ->
        error
        |> Map.get(:errors, [error])
        |> Enum.map_join("; ", &describe/1)
    end
  end

  defp describe(%{field: field, message: message} = error) when not is_nil(field) do
    "#{label(field)} #{interpolate(message, Map.get(error, :vars, []))}"
  end

  defp describe(error), do: Exception.message(error)

  defp label(:current_password), do: "your password"
  defp label(:password_confirmation), do: "the second new password"
  defp label(:password), do: "the new password"
  defp label(field), do: field |> to_string() |> String.replace("_", " ")

  defp interpolate(message, vars) do
    Enum.reduce(vars, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
