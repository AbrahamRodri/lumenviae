defmodule LumenViaeWeb.Live.Mysteries.Edit do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(%{"id" => id}, _session, socket) do
    mystery = Rosary.get_mystery!(id, actor: socket.assigns.current_admin)

    {:ok,
     socket
     |> assign(:page_title, "Edit Mystery")
     |> assign(:mystery, mystery)
     |> assign_edit_form(mystery), temporary_assigns: [return_to: nil]}
  end

  def handle_params(params, _uri, socket) do
    return_to = Map.get(params, "return_to", "/admin/mysteries")
    {:noreply, assign(socket, :return_to, return_to)}
  end

  def handle_event("update_mystery", %{"mystery" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.edit_form, params: params) do
      {:ok, mystery} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mystery updated successfully")
         |> assign(:mystery, mystery)
         |> assign_edit_form(mystery)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update mystery")
         |> assign(:edit_form, form)}
    end
  end

  defp assign_edit_form(socket, mystery) do
    assign(
      socket,
      :edit_form,
      to_form(
        Rosary.form_to_update_mystery(mystery, as: "mystery", actor: socket.assigns.current_admin)
      )
    )
  end
end
