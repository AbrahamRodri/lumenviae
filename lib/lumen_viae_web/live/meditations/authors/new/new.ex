defmodule LumenViaeWeb.Live.Meditations.Authors.New do
  use LumenViaeWeb, :live_view

  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "New Author")
     |> assign(
       :author_form,
       to_form(Rosary.form_to_create_author(as: "author", actor: socket.assigns.current_admin))
     )}
  end

  def handle_event("create_author", %{"author" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.author_form, params: params) do
      {:ok, author} ->
        {:noreply,
         socket
         |> put_flash(:info, "Author created. Upload their portrait below.")
         |> push_navigate(to: "/admin/authors/#{author.id}/edit")}

      {:error, form} ->
        {:noreply, assign(socket, :author_form, form)}
    end
  end
end
