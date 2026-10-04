defmodule LumenViaeWeb.Live.Meditations.Edit do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary
  alias LumenViaeWeb.Live.Admin.History

  def mount(%{"id" => id}, _session, socket) do
    meditation = Rosary.get_meditation!(id, actor: socket.assigns.current_admin)

    {:ok,
     socket
     |> assign(:page_title, "Edit Meditation")
     |> assign(:meditation, meditation)
     |> assign(:mysteries, Rosary.list_mysteries!(actor: socket.assigns.current_admin))
     |> assign_edit_form(meditation), temporary_assigns: [return_to: nil]}
  end

  def handle_params(params, _uri, socket) do
    return_to = Map.get(params, "return_to", "/admin/meditations")
    {:noreply, assign(socket, :return_to, return_to)}
  end

  def handle_event("update_meditation", %{"meditation" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.edit_form, params: params) do
      {:ok, meditation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation updated successfully")
         |> assign(:meditation, meditation)
         |> assign_edit_form(meditation)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update meditation")
         |> assign(:edit_form, form)}
    end
  end

  def handle_event("restore_version", %{"id" => version_id}, socket) do
    case History.restore(socket, socket.assigns.meditation, version_id) do
      {:ok, meditation} ->
        meditation = Rosary.get_meditation!(meditation.id, actor: socket.assigns.current_admin)

        {:noreply,
         socket
         |> put_flash(:info, "Version restored")
         |> assign(:meditation, meditation)
         |> assign_edit_form(meditation)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp assign_edit_form(socket, meditation) do
    socket
    |> History.assign_history(meditation)
    |> assign(
      :edit_form,
      to_form(
        Rosary.form_to_update_meditation(meditation,
          as: "meditation",
          actor: socket.assigns.current_admin
        )
      )
    )
  end
end
