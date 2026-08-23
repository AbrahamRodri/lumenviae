defmodule LumenViaeWeb.Components.ArtworkSection do
  @moduledoc """
  Artwork card for any admin edit page whose record carries the artwork
  columns - meditation sets and authors today.

  Three things in one place, because they are only useful together: upload a
  painting, say where its subject is, and record what it is and where it
  came from.

  The focal point is picked by clicking the painting rather than typed, and
  the three crops beside it are the exact frames the app draws - a 393x470
  set-detail hero, a home card and a mini-player thumbnail - rendered with
  CSS `object-position` from the same normalized pair the API returns and
  SwiftUI consumes. What the curator sees here is what the phone renders.
  An author's portrait is drawn in the same frames, standing in for sets
  with no painting of their own.

  The parent Edit LiveView handles `validate_artwork`, `upload_artwork`,
  `remove_artwork_upload`, `set_focal_point`, `nudge_focal` and
  `update_artwork_meta`.
  """
  use Phoenix.Component

  import LumenViaeWeb.Components.Admin

  alias LumenViae.Curation.ArtworkUpload
  alias LumenViae.Rosary.Artwork

  attr :record, :map, required: true
  attr :intro, :string, required: true
  attr :artwork_url, :string, default: nil
  attr :form, :map, required: true
  attr :upload, :map, required: true
  attr :licenses, :list, required: true
  attr :rules, :string, required: true

  def artwork_section(assigns) do
    assigns =
      assigns
      |> assign(:focal_x, assigns.record.image_focal_x || 0.5)
      |> assign(:focal_y, assigns.record.image_focal_y || 0.5)
      |> assign(:publishable, Artwork.publishable?(assigns.record))

    ~H"""
    <.panel
      title="Artwork"
      description={"#{@intro} #{@rules} Nothing is resized on the server, so upload it at the size you want it shown."}
    >
      <%= if @artwork_url do %>
        <div class="grid lg:grid-cols-2 gap-6 mb-6">
          <div>
            <%!-- Deliberately not phx-update="ignore". The hook moves the
            crosshair itself so it does not lag the pointer, but the painting
            inside this container is server-rendered: ignoring updates here
            left a replaced painting showing the old image while the crops
            beside it showed the new one. The crosshair survives patches
            anyway - LiveView only rewrites an attribute the server actually
            changed. --%>
            <p class="admin-eyebrow mb-1">Focal point</p>
            <p class="text-xs text-admin-ink-soft mb-2">
              Click or drag on the painting to mark the subject. The app keeps this point
              as near the centre of every crop as the frame allows.
            </p>
            <div
              id="focal-target"
              phx-hook="FocalPoint"
              class="relative cursor-crosshair select-none inline-block max-h-[24rem] overflow-hidden rounded border border-admin-hairline"
            >
              <img
                src={@artwork_url}
                alt={@record.image_alt || ""}
                class="max-h-[24rem] w-auto block"
              />
              <div
                data-focal-crosshair
                class="absolute w-6 h-6 -ml-3 -mt-3 rounded-full border-2 border-gold bg-gold/20 pointer-events-none"
                style={"left: #{@focal_x * 100}%; top: #{@focal_y * 100}%"}
              >
              </div>
            </div>

            <div class="mt-3 flex flex-wrap items-center gap-1.5">
              <span class="admin-eyebrow">Nudge</span>
              <.nudge axis="x" delta="-0.01" label="Left" />
              <.nudge axis="x" delta="0.01" label="Right" />
              <.nudge axis="y" delta="-0.01" label="Up" />
              <.nudge axis="y" delta="0.01" label="Down" />
              <span class="text-xs text-admin-ink-faint ml-1">
                {format_focal(@focal_x)}, {format_focal(@focal_y)}
              </span>
            </div>
          </div>

          <div>
            <p class="admin-eyebrow mb-2">How it will be cropped</p>
            <div class="grid grid-cols-3 gap-3">
              <.crop
                title="Set detail hero"
                class="aspect-[393/470]"
                url={@artwork_url}
                focal_x={@focal_x}
                focal_y={@focal_y}
              />
              <.crop
                title="Home card"
                class="aspect-[11/10]"
                url={@artwork_url}
                focal_x={@focal_x}
                focal_y={@focal_y}
              />
              <.crop
                title="Mini player"
                class="aspect-square"
                url={@artwork_url}
                focal_x={@focal_x}
                focal_y={@focal_y}
              />
            </div>

            <p class="text-xs text-admin-ink-soft mt-3">
              Stored as {@record.image_width}x{@record.image_height},
              aligned <strong>{Artwork.alignment(@focal_y)}</strong>.
            </p>
          </div>
        </div>
      <% end %>

      <.callout :if={@artwork_url && !@publishable}>
        This painting is saved but is <strong>not being served</strong>. Artwork needs both a
        description and a licence before the app is shown it; until then the app behaves as if
        there were no painting here.
      </.callout>

      <div class="mb-6">
        <p class="admin-eyebrow mb-2">
          {if @artwork_url, do: "Replace the painting", else: "Upload a painting"}
        </p>
        <.form
          for={%{}}
          phx-change="validate_artwork"
          phx-submit="upload_artwork"
          phx-drop-target={@upload.ref}
        >
          <div class="border border-dashed border-admin-hairline-strong rounded-lg p-5 text-center">
            <.live_file_input upload={@upload} class="hidden" />

            <%= for entry <- @upload.entries do %>
              <div class="flex items-center justify-between bg-admin-sunken p-3 rounded mb-3">
                <div class="text-left">
                  <p class="text-admin-ink">{entry.client_name}</p>
                  <p class="text-xs text-admin-ink-faint">{entry.progress}%</p>
                </div>
                <button
                  type="button"
                  phx-click="remove_artwork_upload"
                  phx-value-ref={entry.ref}
                  class="admin-btn admin-btn-ghost"
                >
                  Remove
                </button>
              </div>

              <%= for error <- upload_errors(@upload, entry) do %>
                <p class="mb-2 text-xs text-danger-strong">{upload_error(error)}</p>
              <% end %>
            <% end %>

            <%= for error <- upload_errors(@upload) do %>
              <p class="mb-2 text-xs text-danger-strong">{upload_error(error)}</p>
            <% end %>

            <%= if @upload.entries == [] do %>
              <label for={@upload.ref} class="cursor-pointer text-[0.8125rem] text-navy">
                Click to choose a JPEG, or drop one here
              </label>
            <% else %>
              <button type="submit" class="admin-btn admin-btn-primary">Upload</button>
            <% end %>
          </div>
        </.form>

        <%= if @artwork_url do %>
          <p class="text-xs text-admin-ink-faint mt-2">
            Uploading a replacement gives the painting a new address, so every cached copy
            in the app refreshes itself. The old file is left in the bucket.
          </p>
        <% end %>
      </div>

      <div class="pt-5 border-t border-admin-hairline">
        <p class="admin-eyebrow mb-3">About the painting</p>
        <.form for={@form} phx-submit="update_artwork_meta">
          <div class="space-y-4">
            <.field
              label="Description"
              hint="What is shown, for readers using VoiceOver. Required before the app is served the painting."
              errors={@form[:image_alt].errors}
            >
              <textarea
                name={@form[:image_alt].name}
                rows="2"
                class="admin-textarea"
                placeholder="Describe what is shown"
              ><%= @form[:image_alt].value || "" %></textarea>
            </.field>

            <div class="grid md:grid-cols-2 gap-4">
              <.field label="Title" errors={@form[:image_title].errors}>
                <input
                  type="text"
                  name={@form[:image_title].name}
                  value={@form[:image_title].value || ""}
                  class="admin-input"
                  placeholder="e.g. Christ Carrying the Cross"
                />
              </.field>

              <.field label="Artist" errors={@form[:image_artist].errors}>
                <input
                  type="text"
                  name={@form[:image_artist].name}
                  value={@form[:image_artist].value || ""}
                  class="admin-input"
                  placeholder="e.g. El Greco"
                />
              </.field>

              <.field label="Year" errors={@form[:image_year].errors}>
                <input
                  type="text"
                  name={@form[:image_year].name}
                  value={@form[:image_year].value || ""}
                  class="admin-input"
                  placeholder="e.g. c. 1580"
                />
              </.field>

              <.field
                label="Licence"
                hint="Required before the app is served the painting."
                errors={@form[:image_license].errors}
              >
                <select name={@form[:image_license].name} class="admin-input">
                  <option value="">Not recorded</option>
                  <option
                    :for={{label, value} <- @licenses}
                    value={value}
                    selected={@form[:image_license].value == value}
                  >
                    {label}
                  </option>
                </select>
              </.field>
            </div>

            <.field label="Source URL" errors={@form[:image_source_url].errors}>
              <input
                type="url"
                name={@form[:image_source_url].name}
                value={@form[:image_source_url].value || ""}
                class="admin-input"
                placeholder="https://www.metmuseum.org/art/collection/search/436574"
              />
            </.field>

            <div class="flex justify-end">
              <button type="submit" class="admin-btn admin-btn-primary">
                Save artwork details
              </button>
            </div>
          </div>
        </.form>
      </div>
    </.panel>
    """
  end

  attr :axis, :string, required: true
  attr :delta, :string, required: true
  attr :label, :string, required: true

  defp nudge(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="nudge_focal"
      phx-value-axis={@axis}
      phx-value-delta={@delta}
      class="admin-btn admin-btn-secondary"
    >
      {@label}
    </button>
    """
  end

  attr :title, :string, required: true
  attr :class, :string, required: true
  attr :url, :string, required: true
  attr :focal_x, :float, required: true
  attr :focal_y, :float, required: true

  defp crop(assigns) do
    ~H"""
    <div>
      <div class={"#{@class} overflow-hidden border border-admin-hairline rounded"}>
        <img
          src={@url}
          alt=""
          class="w-full h-full object-cover"
          style={"object-position: #{Artwork.object_position(@focal_x, @focal_y)}"}
        />
      </div>
      <p class="text-[0.6875rem] text-admin-ink-faint mt-1.5 text-center">{@title}</p>
    </div>
    """
  end

  defp format_focal(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)

  defp upload_error(:too_large) do
    "That file is larger than #{div(ArtworkUpload.max_bytes(), 1024 * 1024)} MB."
  end

  defp upload_error(:not_accepted), do: "Artwork must be a JPEG."
  defp upload_error(:too_many_files), do: "One painting at a time."
  defp upload_error(error), do: "The file could not be accepted (#{inspect(error)})."
end
