defmodule LumenViaeWeb.Live.Meditations.New do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Create Meditation")
     |> assign(:mysteries, Rosary.list_mysteries!())
     |> assign(:filter_category, nil)
     |> assign_meditation_form()}
  end

  def handle_event("create_meditation", %{"meditation" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.meditation_form, params: params) do
      {:ok, meditation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation created successfully")
         |> push_navigate(to: "/admin/meditations/#{meditation.id}/edit")}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create meditation")
         |> assign(:meditation_form, form)}
    end
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    filter = if category == "", do: nil, else: category
    {:noreply, assign(socket, :filter_category, filter)}
  end

  defp assign_meditation_form(socket) do
    assign(
      socket,
      :meditation_form,
      to_form(Rosary.form_to_create_meditation(as: "meditation"))
    )
  end

  defp filtered_mysteries(assigns) do
    case assigns.filter_category do
      nil -> assigns.mysteries
      category -> Enum.filter(assigns.mysteries, fn m -> m.category == category end)
    end
  end
end
