defmodule LumenViaeWeb.Live.Meditations.Sets.Edit do
  use LumenViaeWeb, :live_view
  import LumenViaeWeb.Live.Meditations.Helpers
  alias LumenViae.Rosary.Categories
  alias LumenViaeWeb.Live.Meditations.Filtering
  alias LumenViae.Curation.ArtworkUpload
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork
  alias LumenViae.Rosary.Labels
  alias LumenViaeWeb.Live.Admin.History

  def mount(%{"id" => id}, _session, socket) do
    set =
      Rosary.get_meditation_set_with_ordered_meditations!(id, actor: socket.assigns.current_admin)

    meditations = Rosary.list_meditations!(actor: socket.assigns.current_admin)

    {:ok,
     socket
     |> assign(:page_title, "Edit Meditation Set")
     |> assign(:authors, Rosary.list_authors!(actor: socket.assigns.current_admin))
     |> assign(:meditations, meditations)
     |> assign(:available_authors, Filtering.available_authors(meditations))
     |> assign(:filter_category, nil)
     |> assign(:filter_author, nil)
     |> assign(:search_query, "")
     |> assign(:selected_set_meditations, set.meditations)
     |> assign(:mystery_categories, Categories.options())
     |> assign(:label_vocabulary, Labels.vocabulary())
     |> assign(:max_labels, Labels.max_per_set())
     |> assign(:license_options, Artwork.license_options())
     |> assign(:artwork_rules, ArtworkUpload.rules())
     |> allow_upload(:artwork,
       accept: ~w(.jpg .jpeg),
       max_entries: 1,
       max_file_size: ArtworkUpload.max_bytes()
     )
     |> assign_set(set)}
  end

  def handle_event("update_meditation_set", %{"meditation_set" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.edit_form, params: params) do
      {:ok, set} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation set updated successfully")
         |> assign_set(set)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update meditation set")
         |> assign(:edit_form, form)}
    end
  end

  def handle_event("validate_artwork", _params, socket), do: {:noreply, socket}

  def handle_event("remove_artwork_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :artwork, ref)}
  end

  def handle_event("upload_artwork", _params, socket) do
    set = socket.assigns.meditation_set

    case consume_artwork_upload(socket, set) do
      {:ok, fields} ->
        case Rosary.update_meditation_set_artwork(set, fields,
               actor: socket.assigns.current_admin
             ) do
          {:ok, set} ->
            {:noreply,
             socket
             |> put_flash(:info, artwork_saved_message(set))
             |> assign_set(set)}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "The painting uploaded but could not be saved")}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}

      :no_file ->
        {:noreply, put_flash(socket, :error, "Choose a JPEG first")}
    end
  end

  def handle_event("update_artwork_meta", %{"artwork" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.artwork_form, params: params) do
      {:ok, set} ->
        {:noreply,
         socket
         |> put_flash(:info, artwork_saved_message(set))
         |> assign_set(set)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save the artwork details")
         |> assign(:artwork_form, form)}
    end
  end

  # Pushed by the FocalPoint hook, already clamped to 0..1 and debounced.
  def handle_event("set_focal_point", %{"x" => x, "y" => y}, socket) do
    save_focal_point(socket, %{"image_focal_x" => x, "image_focal_y" => y})
  end

  def handle_event("nudge_focal", %{"axis" => axis, "delta" => delta}, socket) do
    set = socket.assigns.meditation_set

    # Float.parse, not String.to_float: the latter raises on any
    # integer-looking string, so a template emitting delta="1" would take the
    # LiveView down rather than move the crosshair.
    case Float.parse(delta) do
      {delta, _rest} ->
        field = if axis == "x", do: :image_focal_x, else: :image_focal_y
        value = Map.get(set, field) || 0.5

        save_focal_point(socket, %{to_string(field) => clamp(value + delta)})

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("add_label", %{"label" => label}, socket) do
    update_labels(socket, socket.assigns.meditation_set.labels ++ [label])
  end

  def handle_event("remove_label", %{"label" => label}, socket) do
    update_labels(socket, List.delete(socket.assigns.meditation_set.labels, label))
  end

  def handle_event("move_label", %{"label" => label, "direction" => direction}, socket) do
    update_labels(socket, move_label(socket.assigns.meditation_set.labels, label, direction))
  end

  def handle_event("restore_version", %{"id" => version_id}, socket) do
    case History.restore(socket, socket.assigns.meditation_set, version_id) do
      {:ok, set} ->
        set =
          Rosary.get_meditation_set_with_ordered_meditations!(set.id,
            actor: socket.assigns.current_admin
          )

        {:noreply,
         socket
         |> put_flash(:info, "Version restored")
         |> assign_set(set)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("add_to_set", %{"meditation_id" => meditation_id, "order" => order}, socket) do
    set_id = socket.assigns.meditation_set.id

    with {meditation_id_int, ""} <- Integer.parse(meditation_id),
         {order_int, ""} <- Integer.parse(order),
         true <- order_int >= 1 and order_int <= 7 do
      case Rosary.add_meditation_to_set(set_id, meditation_id_int, order_int,
             actor: socket.assigns.current_admin
           ) do
        {:ok, _} ->
          set =
            Rosary.get_meditation_set_with_ordered_meditations!(set_id,
              actor: socket.assigns.current_admin
            )

          {:noreply,
           socket
           |> put_flash(:info, "Meditation added to set")
           |> assign_set(set)
           |> assign(:selected_set_meditations, set.meditations)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add meditation to set")}
      end
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid meditation ID or order (must be 1-7)")}
    end
  end

  def handle_event("update_filters", params, socket) do
    {:noreply,
     socket
     |> assign(:filter_category, Filtering.blank_to_nil(params["category"]))
     |> assign(:filter_author, Filtering.blank_to_nil(params["author"]))
     |> assign(:search_query, String.trim(params["query"] || ""))}
  end

  def handle_event("remove_from_set", %{"meditation_id" => meditation_id}, socket) do
    set_id = socket.assigns.meditation_set.id

    case Integer.parse(meditation_id) do
      {meditation_id_int, ""} ->
        Rosary.remove_meditation_from_set(set_id, meditation_id_int,
          actor: socket.assigns.current_admin
        )

        set =
          Rosary.get_meditation_set_with_ordered_meditations!(set_id,
            actor: socket.assigns.current_admin
          )

        {:noreply,
         socket
         |> put_flash(:info, "Meditation removed from set")
         |> assign_set(set)
         |> assign(:selected_set_meditations, set.meditations)}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid meditation ID")}
    end
  end

  # Persists a label change immediately. Unsaved edits in the Set Details
  # inputs survive it: the forms are rebuilt from the saved set, whose
  # details have not changed, so nothing about those inputs is re-rendered.
  defp update_labels(socket, labels) do
    case Rosary.update_meditation_set(socket.assigns.meditation_set, %{labels: labels},
           actor: socket.assigns.current_admin
         ) do
      {:ok, set} ->
        {:noreply, assign_set(socket, set)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to update labels")}
    end
  end

  defp move_label(labels, label, direction) do
    index = Enum.find_index(labels, &(&1 == label))

    target =
      case direction do
        "up" -> index && index - 1
        "down" -> index && index + 1
        _ -> nil
      end

    if is_nil(target) or target < 0 or target >= length(labels) do
      labels
    else
      labels
      |> List.delete_at(index)
      |> List.insert_at(target, label)
    end
  end

  defp save_focal_point(socket, attrs) do
    case Rosary.update_meditation_set_artwork_metadata(socket.assigns.meditation_set, attrs,
           actor: socket.assigns.current_admin
         ) do
      {:ok, set} ->
        {:noreply, assign_set(socket, set)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to move the focal point")}
    end
  end

  defp clamp(value), do: value |> max(0.0) |> min(1.0) |> Float.round(3)

  defp consume_artwork_upload(socket, set) do
    case uploaded_entries(socket, :artwork) do
      {[_ | _], _} ->
        [result] =
          consume_uploaded_entries(socket, :artwork, fn %{path: path}, _entry ->
            {:ok, ArtworkUpload.upload(File.read!(path), :set, set.id)}
          end)

        result

      _none ->
        :no_file
    end
  end

  # The publish gate lives in the API view, so a curator who has uploaded a
  # painting but not yet described it needs telling here rather than
  # discovering it as a missing hero on the phone.
  defp artwork_saved_message(set) do
    if Artwork.publishable?(set) do
      "Artwork saved"
    else
      "Artwork saved, but not served yet: it still needs a description and a licence"
    end
  end

  # The set and both of its forms, together. Each form holds the set it was
  # built from, so after any write on this page both are rebuilt from the
  # saved one: a form left holding an older copy would hand that copy back
  # as the result of its next save.
  defp assign_set(socket, set) do
    socket
    |> assign(:meditation_set, set)
    |> History.assign_history(set)
    |> assign(
      :edit_form,
      to_form(
        Rosary.form_to_update_meditation_set(set,
          as: "meditation_set",
          actor: socket.assigns.current_admin
        )
      )
    )
    |> assign(:artwork_url, Rosary.artwork_url(set))
    |> assign(
      :artwork_form,
      to_form(
        Rosary.form_to_update_meditation_set_artwork_metadata(set,
          as: "artwork",
          actor: socket.assigns.current_admin
        )
      )
    )
  end
end
