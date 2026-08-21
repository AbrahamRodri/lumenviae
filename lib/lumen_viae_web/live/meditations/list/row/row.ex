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
    <div class="border border-gold/20 rounded-lg overflow-hidden">
      <div class="flex items-start justify-between gap-4 p-4 bg-cream hover:bg-cream-dark transition-colors">
        <div class="flex items-start gap-3 flex-1 min-w-0">
          <input
            type="checkbox"
            checked={@selected}
            phx-click="toggle_selected"
            phx-value-id={@meditation.id}
            class="mt-1.5 h-4 w-4 accent-[#b18b49] cursor-pointer"
          />
          <div class="min-w-0">
            <h4 class="font-work-sans font-semibold text-navy">
              {@meditation.mystery.name}
              {if @meditation.title, do: " - #{@meditation.title}"}
            </h4>
            <p class="font-work-sans text-sm text-brown">
              <%= if @meditation.author do %>
                by {@meditation.author}
              <% end %>
              <%= if @meditation.source do %>
                <span class="italic text-brown-light">({@meditation.source})</span>
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

              <span class="font-work-sans text-xs text-brown-light ml-1">
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
            class="px-3 py-1.5 text-navy border border-navy rounded hover:bg-navy hover:text-white transition-colors font-work-sans text-sm"
          >
            {if @expanded, do: "Hide", else: "View"}
          </button>

          <.link
            navigate={"/admin/meditations/#{@meditation.id}/edit"}
            class="px-3 py-1.5 text-navy border border-navy rounded hover:bg-navy hover:text-white transition-colors font-work-sans text-sm"
          >
            Edit
          </.link>

          <%= if @meditation.archived_at do %>
            <button
              phx-click="unarchive_meditation"
              phx-value-id={@meditation.id}
              class="px-3 py-1.5 text-caution border border-caution rounded hover:bg-caution hover:text-white transition-colors font-work-sans text-sm"
            >
              Unarchive
            </button>
          <% else %>
            <button
              phx-click="archive_meditation"
              phx-value-id={@meditation.id}
              data-confirm="Archive this meditation? It will be hidden from the public site, along with any meditation set that contains it. You can unarchive it at any time."
              class="px-3 py-1.5 text-caution border border-caution rounded hover:bg-caution hover:text-white transition-colors font-work-sans text-sm"
            >
              Archive
            </button>
          <% end %>

          <button
            phx-click="delete_meditation"
            phx-value-id={@meditation.id}
            data-confirm="Are you sure you want to delete this meditation? This cannot be undone - archiving is usually the safer choice."
            class="px-3 py-1.5 text-danger border border-danger rounded hover:bg-danger hover:text-white transition-colors font-work-sans text-sm"
          >
            Delete
          </button>
        </div>
      </div>

      <%= if @expanded do %>
        <div class="p-6 bg-white border-t border-gold/20">
          <div class="prose max-w-none">
            <p class="font-work-sans text-navy whitespace-pre-wrap">{@meditation.content}</p>

            <div class="mt-4 space-y-1">
              <%= if @meditation.source do %>
                <p class="font-work-sans text-sm text-brown-light italic">
                  Source: {@meditation.source}
                </p>
              <% end %>
              <%= if @meditation.audio_url not in [nil, ""] do %>
                <p class="font-work-sans text-sm text-brown-light">
                  Audio S3 key: {@meditation.audio_url}
                </p>
              <% end %>
              <%= if @meditation.tts_annotations != [] do %>
                <p class="font-work-sans text-sm text-brown-light">
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
