defmodule LumenViaeWeb.Live.Mysteries.Edit do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Mystery

  def mount(%{"id" => id}, _session, socket) do
    mystery = Rosary.get_mystery!(id)

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
    case Rosary.update_mystery(socket.assigns.mystery, params) do
      {:ok, mystery} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mystery updated successfully")
         |> assign(:mystery, mystery)
         |> assign_edit_form(mystery)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update mystery")
         |> assign_edit_form(changeset)}
    end
  end

  defp assign_edit_form(socket, %Mystery{} = mystery) do
    assign_edit_form(socket, Rosary.change_mystery(mystery))
  end

  defp assign_edit_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :edit_form, to_form(changeset, as: :mystery))
  end
end
