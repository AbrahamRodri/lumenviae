defmodule LumenViaeWeb.Live.Meditations.Sets.New do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Create Meditation Set")
     |> assign_meditation_set_form()}
  end

  def handle_event("create_meditation_set", params, socket) do
    case Rosary.create_meditation_set(params) do
      {:ok, set} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation set created successfully")
         |> push_navigate(to: "/admin/meditation-sets/#{set.id}/edit")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create meditation set")}
    end
  end

  defp assign_meditation_set_form(socket) do
    assign(
      socket,
      :meditation_set_form,
      to_form(%{"name" => "", "category" => "", "description" => ""})
    )
  end
end
