defmodule LumenViaeWeb.Live.Mysteries.List do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    mysteries = Rosary.list_mysteries()

    {:ok,
     socket
     |> assign(:page_title, "Mysteries")
     |> assign(:mysteries, mysteries)}
  end

  def handle_event("delete_mystery", %{"id" => id}, socket) do
    mystery_id = String.to_integer(id)
    mystery = Rosary.get_mystery!(mystery_id)

    case Rosary.delete_mystery(mystery) do
      {:ok, _mystery} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mystery deleted successfully")
         |> assign(:mysteries, Rosary.list_mysteries())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete mystery")}
    end
  end
end
