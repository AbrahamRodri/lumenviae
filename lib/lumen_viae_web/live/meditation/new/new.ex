defmodule LumenViaeWeb.Live.Meditation.New do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Create Meditation")
     |> assign(:mysteries, Rosary.list_mysteries())
     |> assign(:filter_category, nil)
     |> assign_meditation_form()}
  end

  def handle_event("create_meditation", params, socket) do
    case Rosary.create_meditation(params) do
      {:ok, meditation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation created successfully")
         |> push_navigate(to: "/admin/meditations/#{meditation.id}/edit")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create meditation")}
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
      to_form(%{
        "mystery_id" => "",
        "title" => "",
        "content" => "",
        "author" => "",
        "source" => ""
      })
    )
  end

  defp filtered_mysteries(assigns) do
    case assigns.filter_category do
      nil -> assigns.mysteries
      category -> Enum.filter(assigns.mysteries, fn m -> m.category == category end)
    end
  end
end
