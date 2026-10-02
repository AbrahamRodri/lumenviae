defmodule LumenViaeWeb.Live.Mysteries.New do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Create Mystery")
     |> assign(
       :mystery_form,
       to_form(Rosary.form_to_create_mystery(as: "mystery", actor: socket.assigns.current_admin))
     )}
  end

  def handle_event("create_mystery", %{"mystery" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.mystery_form, params: params) do
      {:ok, mystery} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mystery created successfully")
         |> push_navigate(to: "/admin/mysteries/#{mystery.id}/edit")}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create mystery")
         |> assign(:mystery_form, form)}
    end
  end
end
