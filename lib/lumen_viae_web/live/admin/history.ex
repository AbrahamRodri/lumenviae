defmodule LumenViaeWeb.Live.Admin.History do
  @moduledoc """
  What an edit page needs for its History panel
  (`LumenViaeWeb.Components.History`), so the four pages that show one -
  meditation, set, mystery, author - hold the same few lines rather than
  the same logic four times.

      socket |> History.assign_history(record)

      def handle_event("restore_version", %{"id" => id}, socket) do
        case History.restore(socket, socket.assigns.mystery, id) do
          {:ok, _mystery} -> reload the record, the form and the history
          {:error, message} -> {:noreply, put_flash(socket, :error, message)}
        end
      end
  """
  import Phoenix.Component, only: [assign: 3]

  alias LumenViae.Rosary

  @doc "Assigns `@history` and `@restorable` for `record`, as the signed-in admin."
  def assign_history(socket, record) do
    actor = socket.assigns.current_admin

    socket
    |> assign(:history, Rosary.list_history(record, actor: actor))
    |> assign(:restorable, Rosary.restorable_fields(record))
  end

  @doc """
  Restores `record` to the version `version_id`, as the signed-in admin.
  Returns `{:ok, record}` or `{:error, message}` for the flash.
  """
  def restore(socket, record, version_id) do
    case Rosary.restore_version(record, version_id, actor: socket.assigns.current_admin) do
      {:ok, record} ->
        {:ok, record}

      {:error, error} ->
        {:error, "Could not restore that version: " <> Exception.message(error)}
    end
  end
end
