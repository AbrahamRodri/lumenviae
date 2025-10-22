defmodule LumenViaeWeb.Live.MeditationSet.List do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Meditation Sets")
     |> assign(:meditation_sets, Rosary.list_meditation_sets())
     |> assign(:selected_set, nil)
     |> assign(:selected_set_meditations, [])}
  end

  def handle_event("select_set", %{"set_id" => set_id}, socket) do
    case set_id do
      "" ->
        {:noreply,
         socket
         |> assign(:selected_set, nil)
         |> assign(:selected_set_meditations, [])}

      id ->
        set = Rosary.get_meditation_set_with_ordered_meditations!(id)

        {:noreply,
         socket
         |> assign(:selected_set, set)
         |> assign(:selected_set_meditations, set.meditations)}
    end
  end

  def handle_event("delete_set", %{"id" => id}, socket) do
    set = Rosary.get_meditation_set!(id)

    case Rosary.delete_meditation_set(set) do
      {:ok, _set} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation set deleted successfully")
         |> assign(:meditation_sets, Rosary.list_meditation_sets())
         |> assign(:selected_set, nil)
         |> assign(:selected_set_meditations, [])}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete meditation set")}
    end
  end
end
