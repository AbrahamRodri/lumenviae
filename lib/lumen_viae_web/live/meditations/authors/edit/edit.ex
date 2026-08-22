defmodule LumenViaeWeb.Live.Meditations.Authors.Edit do
  use LumenViaeWeb, :live_view

  alias LumenViae.Curation.ArtworkUpload
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork

  def mount(%{"id" => id}, _session, socket) do
    author = Rosary.get_author!(id)

    {:ok,
     socket
     |> assign(:page_title, "Edit Author")
     |> assign(:author, author)
     |> assign(:license_options, Artwork.license_options())
     |> assign(:artwork_rules, ArtworkUpload.rules())
     |> allow_upload(:artwork,
       accept: ~w(.jpg .jpeg),
       max_entries: 1,
       max_file_size: ArtworkUpload.max_bytes()
     )
     |> assign_edit_form(author)
     |> assign_artwork(author)}
  end

  def handle_event("update_author", %{"author" => params}, socket) do
    case Rosary.update_author(socket.assigns.author, params) do
      {:ok, author} ->
        {:noreply,
         socket
         |> put_flash(:info, "Author updated")
         |> assign(:author, author)
         |> assign_edit_form(author)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update author")
         |> assign_edit_form(changeset)}
    end
  end

  def handle_event("validate_artwork", _params, socket), do: {:noreply, socket}

  def handle_event("remove_artwork_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :artwork, ref)}
  end

  def handle_event("upload_artwork", _params, socket) do
    author = socket.assigns.author

    case consume_artwork_upload(socket, author) do
      {:ok, fields} ->
        case Rosary.update_author_artwork(author, fields) do
          {:ok, author} ->
            {:noreply,
             socket
             |> put_flash(:info, artwork_saved_message(author))
             |> assign(:author, author)
             |> assign_artwork(author)}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "The portrait uploaded but could not be saved")}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}

      :no_file ->
        {:noreply, put_flash(socket, :error, "Choose a JPEG first")}
    end
  end

  def handle_event("update_artwork_meta", %{"artwork" => params}, socket) do
    case Rosary.update_author_artwork_metadata(socket.assigns.author, params) do
      {:ok, author} ->
        {:noreply,
         socket
         |> put_flash(:info, artwork_saved_message(author))
         |> assign(:author, author)
         |> assign_artwork(author)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save the artwork details")
         |> assign(:artwork_form, to_form(changeset, as: :artwork))}
    end
  end

  # Pushed by the FocalPoint hook, already clamped to 0..1 and debounced.
  def handle_event("set_focal_point", %{"x" => x, "y" => y}, socket) do
    save_focal_point(socket, %{"image_focal_x" => x, "image_focal_y" => y})
  end

  def handle_event("nudge_focal", %{"axis" => axis, "delta" => delta}, socket) do
    author = socket.assigns.author

    # Float.parse, not String.to_float: the latter raises on any
    # integer-looking string, so a template emitting delta="1" would take the
    # LiveView down rather than move the crosshair.
    case Float.parse(delta) do
      {delta, _rest} ->
        field = if axis == "x", do: :image_focal_x, else: :image_focal_y
        value = Map.get(author, field) || 0.5

        save_focal_point(socket, %{to_string(field) => clamp(value + delta)})

      :error ->
        {:noreply, socket}
    end
  end

  defp save_focal_point(socket, attrs) do
    case Rosary.update_author_artwork_metadata(socket.assigns.author, attrs) do
      {:ok, author} ->
        {:noreply, socket |> assign(:author, author) |> assign_artwork(author)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to move the focal point")}
    end
  end

  defp clamp(value), do: value |> max(0.0) |> min(1.0) |> Float.round(3)

  defp consume_artwork_upload(socket, author) do
    case uploaded_entries(socket, :artwork) do
      {[_ | _], _} ->
        [result] =
          consume_uploaded_entries(socket, :artwork, fn %{path: path}, _entry ->
            {:ok, ArtworkUpload.upload(File.read!(path), :author, author.id)}
          end)

        result

      _none ->
        :no_file
    end
  end

  # The publish gate lives in the API view, so a curator who has uploaded a
  # portrait but not yet described it needs telling here rather than
  # discovering it as a missing hero on the phone.
  defp artwork_saved_message(author) do
    if Artwork.publishable?(author) do
      "Portrait saved"
    else
      "Portrait saved, but not served yet: it still needs a description and a licence"
    end
  end

  defp assign_artwork(socket, author) do
    socket
    |> assign(:artwork_url, Rosary.artwork_url(author))
    |> assign(:artwork_form, to_form(Rosary.change_author_artwork(author), as: :artwork))
  end

  defp assign_edit_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :edit_form, to_form(changeset, as: :author))
  end

  defp assign_edit_form(socket, author) do
    assign_edit_form(socket, Rosary.change_author(author))
  end
end
