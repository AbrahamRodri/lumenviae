defmodule LumenViaeWeb.Live.Meditations.Edit do
  use LumenViaeWeb, :live_view
  alias LumenViae.Curation.{AudioJobs, AudioRegeneration}
  alias LumenViae.Rosary
  alias LumenViaeWeb.Live.Admin.History
  alias LumenViaeWeb.Live.Meditations.Edit.NarrationPanel

  def mount(%{"id" => id}, _session, socket) do
    meditation = Rosary.get_meditation!(id, actor: socket.assigns.current_admin)

    # Every audio job's outcome, so the Narration panel follows a recording
    # from queued to done without a refresh.
    if connected?(socket), do: AudioJobs.subscribe_all()

    {:ok,
     socket
     |> assign(:page_title, "Edit Meditation")
     |> assign(:meditation, meditation)
     |> assign(:mysteries, Rosary.list_mysteries!(actor: socket.assigns.current_admin))
     |> assign_edit_form(meditation), temporary_assigns: [return_to: nil]}
  end

  def handle_params(params, _uri, socket) do
    return_to = Map.get(params, "return_to", "/admin/meditations")
    {:noreply, assign(socket, :return_to, return_to)}
  end

  def handle_event("update_meditation", %{"meditation" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.edit_form, params: params) do
      {:ok, meditation} ->
        # Read again for its mystery and narrations, which the panels show.
        meditation = Rosary.get_meditation!(meditation.id, actor: socket.assigns.current_admin)

        {:noreply,
         socket
         |> put_flash(:info, "Meditation updated successfully")
         |> assign(:meditation, meditation)
         |> assign_edit_form(meditation)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update meditation")
         |> assign(:edit_form, form)}
    end
  end

  def handle_event("record_narration", %{"voice" => slug} = params, socket) do
    force? = params["force"] == "true"

    results =
      AudioRegeneration.run({:meditation, socket.assigns.meditation.id},
        voices: [slug],
        force: force?,
        only_missing: not force?,
        actor: socket.assigns.current_admin
      )

    {:noreply, socket |> flash_results(results) |> assign_narration()}
  end

  def handle_event("restore_version", %{"id" => version_id}, socket) do
    case History.restore(socket, socket.assigns.meditation, version_id) do
      {:ok, meditation} ->
        meditation = Rosary.get_meditation!(meditation.id, actor: socket.assigns.current_admin)

        {:noreply,
         socket
         |> put_flash(:info, "Version restored")
         |> assign(:meditation, meditation)
         |> assign_edit_form(meditation)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_info({:audio_job, %{key: key}}, socket) do
    if key in socket.assigns.narration_keys do
      meditation =
        Rosary.get_meditation!(socket.assigns.meditation.id, actor: socket.assigns.current_admin)

      # Only the meditation and the panel: the form keeps what is being typed.
      {:noreply, socket |> assign(:meditation, meditation) |> assign_narration()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp assign_narration(socket) do
    meditation = socket.assigns.meditation
    voices = Rosary.list_voices()

    socket
    |> assign(:narration_rows, NarrationPanel.rows(meditation, voices, AudioJobs.in_flight()))
    |> assign(:narration_keys, NarrationPanel.keys(meditation, voices))
  end

  # AudioRegeneration answers one {status, message} per voice it was asked
  # for; a recording queued is :ok, anything else is worth reading.
  defp flash_results(socket, results) do
    case Enum.find(results, fn {status, _message} -> status != :ok end) do
      nil -> put_flash(socket, :info, Enum.map_join(results, " ", &elem(&1, 1)))
      {_status, message} -> put_flash(socket, :error, message)
    end
  end

  defp assign_edit_form(socket, meditation) do
    socket
    |> assign_narration()
    |> History.assign_history(meditation)
    |> assign(
      :edit_form,
      to_form(
        Rosary.form_to_update_meditation(meditation,
          as: "meditation",
          actor: socket.assigns.current_admin
        )
      )
    )
  end
end
