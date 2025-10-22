defmodule LumenViaeWeb.Live.Meditation.Edit do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(%{"id" => id}, _session, socket) do
    meditation = Rosary.get_meditation!(id)

    {:ok,
     socket
     |> assign(:page_title, "Edit Meditation")
     |> assign(:meditation, meditation)
     |> assign(:mysteries, Rosary.list_mysteries())
     |> assign_edit_form(meditation)}
  end

  def handle_event("update_meditation", params, socket) do
    case Rosary.update_meditation(socket.assigns.meditation, params) do
      {:ok, meditation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation updated successfully")
         |> assign(:meditation, meditation)
         |> assign_edit_form(meditation)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update meditation")}
    end
  end

  defp assign_edit_form(socket, meditation) do
    assign(
      socket,
      :edit_form,
      to_form(%{
        "mystery_id" => to_string(meditation.mystery_id),
        "title" => meditation.title || "",
        "content" => meditation.content,
        "author" => meditation.author || "",
        "source" => meditation.source || ""
      })
    )
  end
end
