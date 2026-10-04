defmodule LumenViaeWeb.Live.Mysteries.Edit do
  @moduledoc """
  A mystery's console page: its text, fruit and key verse, and its
  painting in the artwork panel (`LumenViaeWeb.Live.Admin.ArtworkEditing`).
  """
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary
  alias LumenViaeWeb.Live.Admin.ArtworkEditing

  @artwork_events ArtworkEditing.events()

  def mount(%{"id" => id}, _session, socket) do
    mystery = Rosary.get_mystery!(id, actor: socket.assigns.current_admin)

    {:ok,
     socket
     |> assign(:page_title, "Edit Mystery")
     |> assign(:mystery, mystery)
     |> assign_edit_form(mystery)
     |> ArtworkEditing.setup(mystery, artwork_config()), temporary_assigns: [return_to: nil]}
  end

  def handle_params(params, _uri, socket) do
    return_to = Map.get(params, "return_to", "/admin/mysteries")
    {:noreply, assign(socket, :return_to, return_to)}
  end

  def handle_event(event, params, socket) when event in @artwork_events do
    ArtworkEditing.handle(event, params, socket)
  end

  def handle_event("update_mystery", %{"mystery" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.edit_form, params: params) do
      {:ok, mystery} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mystery updated successfully")
         |> assign(:mystery, mystery)
         |> assign_edit_form(mystery)
         |> ArtworkEditing.setup_record(mystery)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update mystery")
         |> assign(:edit_form, form)}
    end
  end

  # The painting's writes go through the artwork actions; after each, both
  # forms are rebuilt from the saved row, since each holds the record it was
  # built from.
  defp artwork_config do
    %{
      scope: :mystery,
      noun: "Painting",
      ensure: fn mystery, _opts -> {:ok, mystery} end,
      record_artwork: &Rosary.update_mystery_artwork/3,
      update_metadata: &Rosary.update_mystery_artwork_metadata/3,
      metadata_form: fn mystery, opts ->
        Rosary.form_to_update_mystery_artwork_metadata(mystery, [as: "artwork"] ++ opts)
      end,
      saved: fn socket, mystery ->
        socket |> assign(:mystery, mystery) |> assign_edit_form(mystery)
      end
    }
  end

  defp assign_edit_form(socket, mystery) do
    assign(
      socket,
      :edit_form,
      to_form(
        Rosary.form_to_update_mystery(mystery, as: "mystery", actor: socket.assigns.current_admin)
      )
    )
  end
end
