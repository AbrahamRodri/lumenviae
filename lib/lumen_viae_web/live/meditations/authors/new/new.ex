defmodule LumenViaeWeb.Live.Meditations.Authors.New do
  use LumenViaeWeb, :live_view

  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "New Author")
     |> assign(:author_form, to_form(Rosary.change_new_author(), as: :author))}
  end

  def handle_event("create_author", %{"author" => params}, socket) do
    case Rosary.create_author(params) do
      {:ok, author} ->
        {:noreply,
         socket
         |> put_flash(:info, "Author created. Upload their portrait below.")
         |> push_navigate(to: "/admin/authors/#{author.id}/edit")}

      {:error, changeset} ->
        {:noreply, assign(socket, :author_form, to_form(changeset, as: :author))}
    end
  end
end
