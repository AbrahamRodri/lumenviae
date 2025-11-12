defmodule LumenViaeWeb.Live.Mysteries.Scripture do
  @moduledoc """
  LiveView for displaying all 20 mysteries of the Rosary with their Biblical references
  """
  use LumenViaeWeb, :live_view

  @categories [
    %{id: "joyful", name: "Joyful"},
    %{id: "sorrowful", name: "Sorrowful"},
    %{id: "glorious", name: "Glorious"},
    %{id: "luminous", name: "Luminous"}
  ]

  @impl true
  def mount(params, _session, socket) do
    selected_category =
      params
      |> Map.get("category", "joyful")
      |> validate_category()

    socket =
      socket
      |> assign(page_title: "The Mysteries of the Rosary")
      |> assign(categories: @categories, selected_category: selected_category)

    {:ok, socket}
  end

  @impl true
  def handle_event("select-category", %{"id" => category_id}, socket) do
    selected_category = validate_category(category_id, socket.assigns.selected_category)

    {:noreply, assign(socket, :selected_category, selected_category)}
  end

  defp validate_category(category_id, default \\ "joyful") do
    case Enum.find(@categories, &(&1.id == category_id)) do
      nil -> default
      _ -> category_id
    end
  end
end
