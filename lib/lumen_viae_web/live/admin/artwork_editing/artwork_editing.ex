defmodule LumenViaeWeb.Live.Admin.ArtworkEditing do
  @moduledoc """
  The artwork panel's events (`LumenViaeWeb.Components.ArtworkSection`) for
  an edit page whose record carries the artwork columns (a mystery, a category card):
  upload a painting, move its focal point, describe it.

  A page calls `setup/3` in `mount`, renders the section from the
  `artwork_*` assigns, and hands every event in `events/0` to `handle/3`.
  What differs between records is the config: the upload scope, the
  domain functions that write the two artwork actions and build the
  metadata form, and what the page does with a saved record.

  The record may not exist yet (a category card is created the first time
  it is saved): `ensure` returns it, creating it if need be, and is called
  only when the curator writes something, never on viewing the page.
  """
  import Phoenix.Component, only: [assign: 3, to_form: 1, to_form: 2]
  import Phoenix.LiveView

  alias LumenViae.Curation.ArtworkUpload
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork

  @events ~w(validate_artwork remove_artwork_upload upload_artwork update_artwork_meta set_focal_point nudge_focal)

  @typedoc """
  * `:scope` - the `ArtworkUpload` scope, which names the bucket prefix
  * `:noun` - what the curator is told was saved: "Painting"
  * `:ensure` - `fn record_or_nil, opts -> {:ok, record} | {:error, term} end`
  * `:record_artwork` / `:update_metadata` - `fn record, attrs, opts -> {:ok, record} | {:error, term} end`
  * `:metadata_form` - `fn record, opts -> AshPhoenix.Form.t() end`
  * `:saved` - `fn socket, record -> socket end`, for the page's own assigns
  """
  @type config :: %{
          scope: ArtworkUpload.scope(),
          noun: String.t(),
          ensure: (map | nil, keyword -> {:ok, map} | {:error, term}),
          record_artwork: (map, map, keyword -> {:ok, map} | {:error, term}),
          update_metadata: (map, map, keyword -> {:ok, map} | {:error, term}),
          metadata_form: (map, keyword -> AshPhoenix.Form.t()),
          saved: (Phoenix.LiveView.Socket.t(), map -> Phoenix.LiveView.Socket.t())
        }

  @doc "The events `handle/3` answers."
  def events, do: @events

  @doc """
  Readies the upload and the `artwork_*` assigns the section reads.
  `record` may be nil when there is nothing saved yet.
  """
  def setup(socket, record, config) do
    socket
    |> assign(:artwork_config, config)
    |> assign(:license_options, Artwork.license_options())
    |> assign(:artwork_rules, ArtworkUpload.rules())
    |> allow_upload(:artwork,
      accept: ~w(.jpg .jpeg),
      max_entries: 1,
      max_file_size: ArtworkUpload.max_bytes()
    )
    |> assign_record(record)
  end

  @doc """
  Rebuilds the `artwork_*` assigns from a record saved elsewhere on the
  page, so the metadata form never holds an older copy of the row.
  """
  def setup_record(socket, record), do: assign_record(socket, record)

  @doc """
  The record as the section draws it: the saved one, or the artwork
  columns at their defaults while there is none.
  """
  def shown(nil),
    do: %{
      image_key: nil,
      image_width: nil,
      image_height: nil,
      image_focal_x: 0.5,
      image_focal_y: 0.5,
      image_alt: nil,
      image_license: nil
    }

  def shown(record), do: record

  @doc "Answers one of `events/0`."
  def handle("validate_artwork", _params, socket), do: {:noreply, socket}

  def handle("remove_artwork_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :artwork, ref)}
  end

  def handle("upload_artwork", _params, socket) do
    config = socket.assigns.artwork_config

    case uploaded_entries(socket, :artwork) do
      {[_ | _], _} ->
        with {:ok, record} <- config.ensure.(socket.assigns.artwork_record, opts(socket)),
             {:ok, fields} <- consume(socket, config.scope, record.id),
             {:ok, record} <- config.record_artwork.(record, fields, opts(socket)) do
          {:noreply, saved(socket, record)}
        else
          {:error, message} when is_binary(message) ->
            {:noreply, put_flash(socket, :error, message)}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "The painting uploaded but could not be saved")}
        end

      _none ->
        {:noreply, put_flash(socket, :error, "Choose a JPEG first")}
    end
  end

  def handle("update_artwork_meta", %{"artwork" => params}, socket) do
    config = socket.assigns.artwork_config

    with {:ok, record} <- config.ensure.(socket.assigns.artwork_record, opts(socket)),
         {:ok, record} <- submit_metadata(socket, record, params) do
      {:noreply, saved(socket, record)}
    else
      {:error, %Phoenix.HTML.Form{} = form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save the artwork details")
         |> assign(:artwork_form, form)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to save the artwork details")}
    end
  end

  # Pushed by the FocalPoint hook, already clamped to 0..1 and debounced.
  def handle("set_focal_point", %{"x" => x, "y" => y}, socket) do
    save_focal_point(socket, %{"image_focal_x" => x, "image_focal_y" => y})
  end

  def handle("nudge_focal", %{"axis" => axis, "delta" => delta}, socket) do
    # Float.parse, not String.to_float: the latter raises on an
    # integer-looking string such as "1".
    case Float.parse(delta) do
      {delta, _rest} ->
        field = if axis == "x", do: :image_focal_x, else: :image_focal_y
        value = Map.get(shown(socket.assigns.artwork_record), field) || 0.5

        save_focal_point(socket, %{to_string(field) => clamp(value + delta)})

      :error ->
        {:noreply, socket}
    end
  end

  # The focal point can only be set on a painting that is shown, so the
  # record exists by then.
  defp save_focal_point(socket, attrs) do
    config = socket.assigns.artwork_config

    case socket.assigns.artwork_record do
      nil ->
        {:noreply, socket}

      record ->
        case config.update_metadata.(record, attrs, opts(socket)) do
          {:ok, record} ->
            {:noreply, assign_record(socket, record) |> config.saved.(record)}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to move the focal point")}
        end
    end
  end

  # A form built from the record now saved, so a card created in this same
  # save is the one written.
  defp submit_metadata(socket, record, params) do
    form = socket.assigns.artwork_config.metadata_form.(record, opts(socket))

    case AshPhoenix.Form.submit(form, params: params) do
      {:ok, record} -> {:ok, record}
      {:error, form} -> {:error, to_form(form, as: "artwork")}
    end
  end

  defp consume(socket, scope, id) do
    [result] =
      consume_uploaded_entries(socket, :artwork, fn %{path: path}, _entry ->
        {:ok, ArtworkUpload.upload(File.read!(path), scope, id)}
      end)

    result
  end

  # The publish gate lives in the API, so a curator who has uploaded a
  # painting but not yet described it needs telling here rather than
  # discovering it as a missing painting on the phone.
  defp saved(socket, record) do
    noun = socket.assigns.artwork_config.noun

    message =
      if Artwork.publishable?(record),
        do: "#{noun} saved",
        else: "#{noun} saved, but not served yet: it still needs a description and a licence"

    socket
    |> put_flash(:info, message)
    |> assign_record(record)
    |> socket.assigns.artwork_config.saved.(record)
  end

  defp assign_record(socket, record) do
    config = socket.assigns.artwork_config

    form =
      case record do
        nil -> to_form(%{}, as: "artwork")
        record -> to_form(config.metadata_form.(record, opts(socket)))
      end

    socket
    |> assign(:artwork_record, record)
    |> assign(:artwork_url, record && Rosary.artwork_url(record))
    |> assign(:artwork_form, form)
  end

  defp opts(socket), do: [actor: socket.assigns.current_admin]

  defp clamp(value), do: value |> max(0.0) |> min(1.0) |> Float.round(3)
end
