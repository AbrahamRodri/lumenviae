defmodule LumenViaeWeb.Live.Meditations.List.Row do
  @moduledoc """
  A single meditation row in the admin meditations list, with selection
  checkbox, status badges, actions, and expandable content. Stateless;
  events are handled by the parent LiveView.
  """
  use LumenViaeWeb, :html

  attr :meditation, :map, required: true
  attr :expanded, :boolean, default: false
  attr :selected, :boolean, default: false

  def meditation_row(assigns) do
    ~H"""
    <div class="border border-gray-200 rounded-lg overflow-hidden">
      <div class="flex items-start justify-between gap-4 p-4 bg-gray-50 hover:bg-gray-100 transition-colors">
        <div class="flex items-start gap-3 flex-1 min-w-0">
          <input
            type="checkbox"
            checked={@selected}
            phx-click="toggle_selected"
            phx-value-id={@meditation.id}
            class="mt-1.5 h-4 w-4 accent-[#b18b49] cursor-pointer"
          />
          <div class="min-w-0">
            <h4 class="font-crimson font-semibold text-navy">
              {@meditation.mystery.name}
              {if @meditation.title, do: " - #{@meditation.title}"}
            </h4>
            <p class="font-crimson text-sm text-gray-600">
              <%= if @meditation.author do %>
                by {@meditation.author}
              <% end %>
              <%= if @meditation.source do %>
                <span class="italic text-gray-500">({@meditation.source})</span>
              <% end %>
            </p>
            <div class="flex flex-wrap items-center gap-1.5 mt-2">
              <.admin_badge tone="navy">
                {String.replace(@meditation.mystery.category, "_", " ")}
              </.admin_badge>

              <%= if @meditation.archived_at do %>
                <.admin_badge tone="gray">Archived</.admin_badge>
              <% end %>

              <%= if @meditation.audio_url in [nil, ""] do %>
                <.admin_badge tone="amber">No audio</.admin_badge>
              <% else %>
                <.admin_badge tone="green" title={@meditation.audio_url}>Audio</.admin_badge>
              <% end %>

              <%= if @meditation.meditation_sets == [] do %>
                <.admin_badge tone="amber">Not in a set</.admin_badge>
              <% else %>
                <%= for set <- @meditation.meditation_sets do %>
                  <.admin_badge tone="gold" title={"In set: #{set.name}"}>{set.name}</.admin_badge>
                <% end %>
              <% end %>

              <span class="font-crimson text-xs text-gray-400 ml-1">
                ID {@meditation.id} &middot; added {Calendar.strftime(
                  @meditation.inserted_at,
                  "%b %d, %Y"
                )}
              </span>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-2 flex-shrink-0">
          <button
            phx-click="toggle_meditation"
            phx-value-id={@meditation.id}
            class="px-3 py-1.5 text-navy border border-navy rounded hover:bg-navy hover:text-white transition-colors font-crimson text-sm"
          >
            {if @expanded, do: "Hide", else: "View"}
          </button>

          <.link
            navigate={"/admin/meditations/#{@meditation.id}/edit"}
            class="px-3 py-1.5 text-navy border border-navy rounded hover:bg-navy hover:text-white transition-colors font-crimson text-sm"
          >
            Edit
          </.link>

          <%= if @meditation.archived_at do %>
            <button
              phx-click="unarchive_meditation"
              phx-value-id={@meditation.id}
              class="px-3 py-1.5 text-amber-700 border border-amber-700 rounded hover:bg-amber-700 hover:text-white transition-colors font-crimson text-sm"
            >
              Unarchive
            </button>
          <% else %>
            <button
              phx-click="archive_meditation"
              phx-value-id={@meditation.id}
              data-confirm="Archive this meditation? It will be hidden from the public site, along with any meditation set that contains it. You can unarchive it at any time."
              class="px-3 py-1.5 text-amber-700 border border-amber-700 rounded hover:bg-amber-700 hover:text-white transition-colors font-crimson text-sm"
            >
              Archive
            </button>
          <% end %>

          <button
            phx-click="delete_meditation"
            phx-value-id={@meditation.id}
            data-confirm="Are you sure you want to delete this meditation? This cannot be undone - archiving is usually the safer choice."
            class="px-3 py-1.5 text-red-600 border border-red-600 rounded hover:bg-red-600 hover:text-white transition-colors font-crimson text-sm"
          >
            Delete
          </button>
        </div>
      </div>

      <%= if @expanded do %>
        <div class="p-6 bg-white border-t border-gray-200">
          <div class="prose max-w-none">
            <p class="font-crimson text-gray-800 whitespace-pre-wrap">{@meditation.content}</p>

            <div class="mt-4 space-y-1">
              <%= if @meditation.source do %>
                <p class="font-crimson text-sm text-gray-500 italic">
                  Source: {@meditation.source}
                </p>
              <% end %>
              <%= if @meditation.audio_url not in [nil, ""] do %>
                <p class="font-crimson text-sm text-gray-500">
                  Audio S3 key: {@meditation.audio_url}
                </p>
              <% end %>
              <%= if @meditation.tts_annotations != [] do %>
                <p class="font-crimson text-sm text-gray-500">
                  Narration pauses: {length(@meditation.tts_annotations)}
                </p>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
