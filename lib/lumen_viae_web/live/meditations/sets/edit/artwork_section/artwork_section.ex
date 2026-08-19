defmodule LumenViaeWeb.Live.Meditations.Sets.Edit.ArtworkSection do
  @moduledoc """
  Artwork card for the meditation set edit page.

  Three things in one place, because they are only useful together: upload a
  painting, say where its subject is, and record what it is and where it
  came from.

  The focal point is picked by clicking the painting rather than typed, and
  the three crops beside it are the exact frames the app draws - a 393x470
  set-detail hero, a home card and a mini-player thumbnail - rendered with
  CSS `object-position` from the same normalized pair the API returns and
  SwiftUI consumes. What the curator sees here is what the phone renders.

  The parent Edit LiveView handles `validate_artwork`, `upload_artwork`,
  `remove_artwork_upload`, `set_focal_point`, `nudge_focal` and
  `update_artwork_meta`.
  """
  use Phoenix.Component

  import LumenViaeWeb.CoreComponents, only: [translate_error: 1]

  alias LumenViae.Curation.ArtworkUpload
  alias LumenViae.Rosary.Artwork

  attr :set, :map, required: true
  attr :artwork_url, :string, default: nil
  attr :form, :map, required: true
  attr :upload, :map, required: true
  attr :licenses, :list, required: true
  attr :rules, :string, required: true

  def artwork_section(assigns) do
    assigns =
      assigns
      |> assign(:focal_x, assigns.set.image_focal_x || 0.5)
      |> assign(:focal_y, assigns.set.image_focal_y || 0.5)
      |> assign(:publishable, Artwork.publishable?(assigns.set))

    ~H"""
    <div class="bg-white border-l-4 border-gold p-8 mb-8">
      <h3 class="font-cinzel text-2xl text-navy mb-2">Artwork</h3>
      <p class="font-work-sans text-brown text-sm mb-6">
        The painting behind the set on the app's detail screen. {@rules} Nothing is resized on the server, so upload it at the size you want it shown.
      </p>

      <%= if @artwork_url do %>
        <div class="grid lg:grid-cols-2 gap-8 mb-8">
          <div>
            <%!-- Deliberately not phx-update="ignore". The hook moves the
            crosshair itself so it does not lag the pointer, but the painting
            inside this container is server-rendered: ignoring updates here
            left a replaced painting showing the old image while the crops
            beside it showed the new one. The crosshair survives patches
            anyway - LiveView only rewrites an attribute the server actually
            changed. --%>
            <h4 class="font-cinzel text-lg text-navy mb-3">Focal point</h4>
            <p class="font-work-sans text-brown text-sm mb-3">
              Click or drag on the painting to mark the subject. The app keeps this point
              as near the centre of every crop as the frame allows.
            </p>
            <div
              id="focal-target"
              phx-hook="FocalPoint"
              class="relative cursor-crosshair select-none inline-block max-h-[28rem] overflow-hidden"
            >
              <img src={@artwork_url} alt={@set.image_alt || ""} class="max-h-[28rem] w-auto block" />
              <div
                data-focal-crosshair
                class="absolute w-6 h-6 -ml-3 -mt-3 rounded-full border-2 border-gold bg-gold/20 pointer-events-none"
                style={"left: #{@focal_x * 100}%; top: #{@focal_y * 100}%"}
              >
              </div>
            </div>

            <div class="mt-4 flex flex-wrap items-center gap-2">
              <span class="font-cinzel text-xs text-navy uppercase tracking-wide">
                Nudge
              </span>
              <.nudge axis="x" delta="-0.01" label="Left" />
              <.nudge axis="x" delta="0.01" label="Right" />
              <.nudge axis="y" delta="-0.01" label="Up" />
              <.nudge axis="y" delta="0.01" label="Down" />
              <span class="font-work-sans text-brown text-sm ml-2">
                {format_focal(@focal_x)}, {format_focal(@focal_y)}
              </span>
            </div>
          </div>

          <div>
            <h4 class="font-cinzel text-lg text-navy mb-3">How it will be cropped</h4>
            <div class="grid grid-cols-3 gap-4">
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

            <p class="font-work-sans text-brown text-sm mt-4">
              Stored as {@set.image_width}x{@set.image_height},
              aligned <strong>{Artwork.alignment(@focal_y)}</strong>.
            </p>
          </div>
        </div>
      <% end %>

      <%= if @artwork_url && !@publishable do %>
        <div class="mb-8 border-l-4 border-amber-600 bg-amber-50 p-4">
          <p class="font-work-sans text-amber-800 text-sm">
            This painting is saved but is <strong>not being served</strong>. Artwork needs both
            a description and a licence before the app is shown it; the app falls back to the
            mystery category's bundled painting until then.
          </p>
        </div>
      <% end %>

      <div class="mb-8">
        <h4 class="font-cinzel text-lg text-navy mb-3">
          {if @artwork_url, do: "Replace the painting", else: "Upload a painting"}
        </h4>
        <.form
          for={%{}}
          phx-change="validate_artwork"
          phx-submit="upload_artwork"
          phx-drop-target={@upload.ref}
        >
          <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center">
            <.live_file_input upload={@upload} class="hidden" />

            <%= for entry <- @upload.entries do %>
              <div class="flex items-center justify-between bg-cream p-4 rounded mb-4">
                <div class="text-left">
                  <p class="font-work-sans text-navy">{entry.client_name}</p>
                  <p class="font-work-sans text-brown text-sm">{entry.progress}%</p>
                </div>
                <button
                  type="button"
                  phx-click="remove_artwork_upload"
                  phx-value-ref={entry.ref}
                  class="text-red-600 hover:text-red-800 font-work-sans text-sm"
                >
                  Remove
                </button>
              </div>

              <%= for error <- upload_errors(@upload, entry) do %>
                <p class="mb-3 text-sm text-red-600 font-work-sans">{upload_error(error)}</p>
              <% end %>
            <% end %>

            <%= for error <- upload_errors(@upload) do %>
              <p class="mb-3 text-sm text-red-600 font-work-sans">{upload_error(error)}</p>
            <% end %>

            <%= if @upload.entries == [] do %>
              <label for={@upload.ref} class="cursor-pointer font-work-sans text-navy">
                Click to choose a JPEG, or drop one here
              </label>
            <% else %>
              <button
                type="submit"
                class="bg-navy text-white px-6 py-2 rounded hover:bg-gold hover:text-navy transition-colors font-work-sans"
              >
                Upload
              </button>
            <% end %>
          </div>
        </.form>

        <%= if @artwork_url do %>
          <p class="font-work-sans text-brown text-xs mt-3">
            Uploading a replacement gives the painting a new address, so every cached copy
            in the app refreshes itself. The old file is left in the bucket.
          </p>
        <% end %>
      </div>

      <div>
        <h4 class="font-cinzel text-lg text-navy mb-3">About the painting</h4>
        <.form for={@form} phx-submit="update_artwork_meta">
          <div class="space-y-4">
            <div>
              <label class="font-work-sans text-navy font-semibold block mb-2">
                Description
              </label>
              <textarea
                name={@form[:image_alt].name}
                rows="2"
                class="w-full p-3 border border-gray-300 rounded font-work-sans text-black"
                placeholder="Describe what is shown, for readers using VoiceOver"
              ><%= @form[:image_alt].value || "" %></textarea>
              <.errors field={@form[:image_alt]} />
            </div>

            <div class="grid md:grid-cols-2 gap-4">
              <div>
                <label class="font-work-sans text-navy font-semibold block mb-2">Title</label>
                <input
                  type="text"
                  name={@form[:image_title].name}
                  value={@form[:image_title].value || ""}
                  class="w-full p-3 border border-gray-300 rounded font-work-sans text-black"
                  placeholder="e.g., Christ Carrying the Cross"
                />
                <.errors field={@form[:image_title]} />
              </div>

              <div>
                <label class="font-work-sans text-navy font-semibold block mb-2">Artist</label>
                <input
                  type="text"
                  name={@form[:image_artist].name}
                  value={@form[:image_artist].value || ""}
                  class="w-full p-3 border border-gray-300 rounded font-work-sans text-black"
                  placeholder="e.g., El Greco"
                />
                <.errors field={@form[:image_artist]} />
              </div>

              <div>
                <label class="font-work-sans text-navy font-semibold block mb-2">Year</label>
                <input
                  type="text"
                  name={@form[:image_year].name}
                  value={@form[:image_year].value || ""}
                  class="w-full p-3 border border-gray-300 rounded font-work-sans text-black"
                  placeholder="e.g., c. 1580"
                />
                <.errors field={@form[:image_year]} />
              </div>

              <div>
                <label class="font-work-sans text-navy font-semibold block mb-2">Licence</label>
                <select
                  name={@form[:image_license].name}
                  class="w-full p-3 border border-gray-300 rounded font-work-sans text-black"
                >
                  <option value="">Not recorded</option>
                  <%= for {label, value} <- @licenses do %>
                    <option value={value} selected={@form[:image_license].value == value}>
                      {label}
                    </option>
                  <% end %>
                </select>
                <.errors field={@form[:image_license]} />
              </div>
            </div>

            <div>
              <label class="font-work-sans text-navy font-semibold block mb-2">Source URL</label>
              <input
                type="url"
                name={@form[:image_source_url].name}
                value={@form[:image_source_url].value || ""}
                class="w-full p-3 border border-gray-300 rounded font-work-sans text-black"
                placeholder="https://www.metmuseum.org/art/collection/search/436574"
              />
              <.errors field={@form[:image_source_url]} />
            </div>

            <div class="flex justify-end">
              <button
                type="submit"
                class="bg-navy text-white px-6 py-3 rounded hover:bg-gold hover:text-navy transition-colors font-work-sans font-semibold"
              >
                Save Artwork Details
              </button>
            </div>
          </div>
        </.form>
      </div>
    </div>
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
      class="px-3 py-1 text-navy border border-navy rounded hover:bg-navy hover:text-white transition-colors font-work-sans text-sm"
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
      <div class={"#{@class} overflow-hidden border border-gold/40"}>
        <img
          src={@url}
          alt=""
          class="w-full h-full object-cover"
          style={"object-position: #{Artwork.object_position(@focal_x, @focal_y)}"}
        />
      </div>
      <p class="font-cinzel text-xs text-navy mt-2 text-center">{@title}</p>
    </div>
    """
  end

  attr :field, :map, required: true

  defp errors(assigns) do
    ~H"""
    <%= for error <- @field.errors do %>
      <p class="mt-2 text-sm text-red-600 font-work-sans">{translate_error(error)}</p>
    <% end %>
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
