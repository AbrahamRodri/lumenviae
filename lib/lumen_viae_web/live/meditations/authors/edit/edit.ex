defmodule LumenViaeWeb.Live.Meditations.Authors.Edit do
  use LumenViaeWeb, :live_view

  alias LumenViae.Rosary

  def mount(%{"id" => id}, _session, socket) do
    author = Rosary.get_author!(id)

    {:ok,
     socket
     |> assign(:page_title, "Edit Author")
     |> assign(:author, author)
     |> assign_edit_form(author)}
  end

  def handle_event("update_author", %{"author" => params}, socket) do
    case Rosary.update_author(socket.assigns.author, params) do
      {:ok, author} ->
        {:noreply,
         socket
         |> put_flash(:info, "Author updated")
         |> assign(:author, author)
         |> assign_edit_form(author)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update author")
         |> assign_edit_form(changeset)}
    end
  end

  defp assign_edit_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :edit_form, to_form(changeset, as: :author))
  end

  defp assign_edit_form(socket, author) do
    assign_edit_form(socket, Rosary.change_author(author))
  end
end
