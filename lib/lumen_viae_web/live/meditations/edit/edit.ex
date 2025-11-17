defmodule LumenViaeWeb.Live.Meditations.Edit do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Meditation

  def mount(%{"id" => id}, _session, socket) do
    meditation = Rosary.get_meditation!(id)

    {:ok,
     socket
     |> assign(:page_title, "Edit Meditation")
     |> assign(:meditation, meditation)
     |> assign(:mysteries, Rosary.list_mysteries())
     |> assign_edit_form(meditation), temporary_assigns: [return_to: nil]}
  end

  def handle_params(params, _uri, socket) do
    return_to = Map.get(params, "return_to", "/admin/meditations")
    {:noreply, assign(socket, :return_to, return_to)}
  end

  def handle_event("update_meditation", %{"meditation" => params}, socket) do
    case Rosary.update_meditation(socket.assigns.meditation, params) do
      {:ok, meditation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation updated successfully")
         |> assign(:meditation, meditation)
         |> assign_edit_form(meditation)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update meditation")
         |> assign_edit_form(changeset)}
    end
  end

  defp assign_edit_form(socket, %Meditation{} = meditation) do
    assign_edit_form(socket, Rosary.change_meditation(meditation))
  end

  defp assign_edit_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :edit_form, to_form(changeset, as: :meditation))
  end
end
