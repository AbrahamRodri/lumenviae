defmodule LumenViaeWeb.Live.Meditations.List.Row do
  @moduledoc """
  One meditation as a table row: selection checkbox, status columns,
  actions, and an expansion holding the text itself.

  Stateless; events are handled by the parent LiveView.
  """
  use LumenViaeWeb, :html

  alias LumenViae.CentralTime
  alias LumenViae.Rosary

  attr :meditation, :map, required: true
  attr :expanded, :boolean, default: false
  attr :selected, :boolean, default: false

  def meditation_row(assigns) do
    ~H"""
    <tr class={[@expanded && "bg-admin-sunken", @selected && "bg-navy/[0.03]"]}>
      <td class="w-8">
        <input
          type="checkbox"
          checked={@selected}
          phx-click="toggle_selected"
          phx-value-id={@meditation.id}
          aria-label={"Select meditation #{@meditation.id}"}
          class="size-3.5 accent-navy cursor-pointer align-middle"
        />
      </td>

      <td>
        <div class="flex items-start gap-2">
          <button
            type="button"
            phx-click="toggle_meditation"
            phx-value-id={@meditation.id}
            class="mt-0.5 text-admin-ink-faint hover:text-admin-ink shrink-0"
            aria-label={if @expanded, do: "Collapse meditation", else: "Read meditation"}
          >
            <span
              class={[
                if(@expanded, do: "hero-chevron-down", else: "hero-chevron-right"),
                "size-4 block"
              ]}
              aria-hidden="true"
            />
          </button>
          <div class="min-w-0">
            <.link
              navigate={"/admin/meditations/#{@meditation.id}/edit"}
              class="font-medium text-admin-ink hover:text-navy"
            >
              {@meditation.mystery.name}
            </.link>
            <p :if={@meditation.title} class="text-xs text-admin-ink-soft truncate max-w-sm">
              {@meditation.title}
            </p>
          </div>
        </div>
      </td>

      <td><.category_badge category={@meditation.mystery.category} /></td>

      <td class="text-admin-ink-soft">
        <span :if={@meditation.author}>{@meditation.author}</span>
        <span :if={is_nil(@meditation.author)} class="text-admin-ink-faint">&mdash;</span>
        <p :if={@meditation.source} class="text-xs text-admin-ink-faint truncate max-w-[14rem]">
          {@meditation.source}
        </p>
      </td>

      <td>
        <div class="flex flex-wrap gap-1">
          <.admin_badge
            :for={set <- @meditation.meditation_sets}
            tone="gold"
            title={"In set: #{set.name}"}
          >
            {set.name}
          </.admin_badge>
          <.admin_badge :if={@meditation.meditation_sets == []} tone="amber">
            Not in a set
          </.admin_badge>
        </div>
      </td>

      <td>
        <.admin_badge
          :if={@meditation.audio_url not in [nil, ""]}
          tone="green"
          title={@meditation.audio_url}
        >
          Audio
        </.admin_badge>
        <.admin_badge :if={@meditation.audio_url in [nil, ""]} tone="amber">No audio</.admin_badge>
      </td>

      <td>
        <.admin_badge :if={@meditation.archived_at} tone="red">Archived</.admin_badge>
        <.admin_badge :if={is_nil(@meditation.archived_at)} tone="green">Active</.admin_badge>
      </td>

      <td>
        <div class="flex items-center justify-end gap-1">
          <.link
            navigate={"/admin/meditations/#{@meditation.id}/edit"}
            class="admin-btn admin-btn-secondary"
          >
            Edit
          </.link>

          <button
            :if={@meditation.archived_at}
            type="button"
            phx-click="unarchive_meditation"
            phx-value-id={@meditation.id}
            class="admin-btn admin-btn-secondary"
          >
            Restore
          </button>
          <button
            :if={is_nil(@meditation.archived_at)}
            type="button"
            phx-click="archive_meditation"
            phx-value-id={@meditation.id}
            data-confirm="Archive this meditation? It will be hidden from the public site, along with any meditation set that contains it. You can restore it at any time."
            class="admin-btn admin-btn-secondary"
            title="Archive"
          >
            <span class="hero-archive-box size-3.5" aria-hidden="true" />
          </button>

          <button
            type="button"
            phx-click="delete_meditation"
            phx-value-id={@meditation.id}
            data-confirm="Permanently delete this meditation? This cannot be undone - archiving is usually the safer choice."
            class="admin-btn admin-btn-danger"
            aria-label="Delete meditation"
          >
            <span class="hero-trash size-3.5" aria-hidden="true" />
          </button>
        </div>
      </td>
    </tr>

    <tr :if={@expanded} class="bg-admin-sunken">
      <td colspan="8" class="pt-0">
        <div class="pl-8 pr-2 pb-2 max-w-3xl">
          <p class="whitespace-pre-wrap text-admin-ink leading-relaxed">
            {@meditation.content}
          </p>
          <dl class="flex flex-wrap gap-x-6 gap-y-1 mt-3 text-xs text-admin-ink-faint">
            <div :if={@meditation.source}>
              <dt class="inline admin-eyebrow">Source</dt>
              <dd class="inline ml-1">{@meditation.source}</dd>
            </div>
            <div :if={@meditation.audio_url not in [nil, ""]}>
              <dt class="inline admin-eyebrow">Audio file</dt>
              <dd class="inline ml-1">{@meditation.audio_url}</dd>
            </div>
            <div :if={@meditation.audio_url not in [nil, ""]}>
              <dt class="inline admin-eyebrow">Voices</dt>
              <dd class="inline ml-1">{narration_voices(@meditation)}</dd>
            </div>
            <div :if={@meditation.tts_annotations != []}>
              <dt class="inline admin-eyebrow">Narration pauses</dt>
              <dd class="inline ml-1">{length(@meditation.tts_annotations)}</dd>
            </div>
            <div>
              <dt class="inline admin-eyebrow">Added</dt>
              <dd class="inline ml-1">
                {Calendar.strftime(@meditation.inserted_at, "%b %-d, %Y")}
              </dd>
            </div>
            <div>
              <dt class="inline admin-eyebrow">Updated</dt>
              <dd class="inline ml-1">{CentralTime.format(@meditation.updated_at)}</dd>
            </div>
          </dl>
        </div>
      </td>
    </tr>
    """
  end

  # Which voices have recorded this meditation, or a plain "none" for a
  # filename with no object behind it yet (an import whose audio failed, or
  # a set awaiting regeneration).
  defp narration_voices(meditation) do
    case Rosary.meditation_narrations(meditation) do
      [] -> "none"
      narrations -> Enum.map_join(narrations, ", ", & &1.voice.slug)
    end
  end
end
