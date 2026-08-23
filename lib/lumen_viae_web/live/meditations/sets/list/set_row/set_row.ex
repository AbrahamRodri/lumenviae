defmodule LumenViaeWeb.Live.Meditations.Sets.List.SetRow do
  @moduledoc """
  One meditation set as a table row, with an inline expansion showing the
  set's ordered meditations.

  A row rather than a card: the whole point of this screen is comparing sets
  to each other - which are short, which have no painting, which nobody can
  see - and columns compare where stacked cards do not. Stateless; events
  are handled by the parent LiveView.
  """
  use LumenViaeWeb, :html

  alias LumenViae.Rosary
  alias LumenViaeWeb.Live.Meditations.Sets.Filtering, as: SetFiltering

  attr :set, :map, required: true
  attr :stats, :map, required: true
  attr :hidden, :boolean, default: false
  attr :expanded, :boolean, default: false
  attr :expanded_meditations, :list, default: []

  def set_row(assigns) do
    assigns =
      assigns
      |> assign(:counts, Map.get(assigns.stats, assigns.set.id, default_counts()))
      |> assign(:expected, Rosary.expected_meditation_count(assigns.set.category))
      |> assign(:artwork, SetFiltering.artwork_state(assigns.set))

    ~H"""
    <tr class={@expanded && "bg-admin-sunken"}>
      <td>
        <div class="flex items-start gap-2">
          <button
            type="button"
            phx-click="toggle_expand"
            phx-value-id={@set.id}
            class="mt-0.5 text-admin-ink-faint hover:text-admin-ink shrink-0"
            aria-label={if @expanded, do: "Collapse #{@set.name}", else: "Expand #{@set.name}"}
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
              navigate={"/admin/meditation-sets/#{@set.id}/edit"}
              class="font-medium text-admin-ink hover:text-navy"
            >
              {@set.name}
            </.link>
            <p :if={@set.description} class="text-admin-ink-faint text-xs truncate max-w-md">
              {@set.description}
            </p>
          </div>
        </div>
      </td>

      <td><.category_badge category={@set.category} /></td>

      <td>
        <span class={[
          "font-medium",
          if(@counts.meditation_count == @expected,
            do: "text-admin-ink",
            else: "text-caution-strong"
          )
        ]}>
          {@counts.meditation_count}
        </span>
        <span class="text-admin-ink-faint">/ {@expected}</span>
      </td>

      <td>
        <span :if={@counts.meditation_count == 0} class="text-admin-ink-faint">&mdash;</span>
        <span
          :if={@counts.meditation_count > 0}
          class={[
            "font-medium",
            if(@counts.audio_count == @counts.meditation_count,
              do: "text-admin-ink",
              else: "text-caution-strong"
            )
          ]}
        >
          {@counts.audio_count}/{@counts.meditation_count}
        </span>
      </td>

      <td><.artwork_badge state={@artwork} /></td>

      <td>
        <div class="flex flex-wrap gap-1">
          <.admin_badge :for={label <- @set.labels} tone="gold">{label}</.admin_badge>
          <.admin_badge
            :if={@set.labels == []}
            tone="amber"
            title={"No labels yet - the app files this set under \"More\" in its picker"}
          >
            None
          </.admin_badge>
        </div>
      </td>

      <td class="text-admin-ink-soft">
        <span :if={byline(@set)}>{byline(@set)}</span>
        <span :if={is_nil(byline(@set))} class="text-admin-ink-faint">&mdash;</span>
      </td>

      <td>
        <.admin_badge
          :if={@hidden}
          tone="red"
          title="This set contains an archived meditation, so neither the site nor the app will show it."
        >
          Hidden
        </.admin_badge>
        <.admin_badge :if={!@hidden} tone="green">Live</.admin_badge>
      </td>

      <td>
        <div class="flex items-center justify-end gap-1">
          <.link
            navigate={"/admin/meditation-sets/#{@set.id}/edit"}
            class="admin-btn admin-btn-secondary"
          >
            Edit
          </.link>
          <button
            type="button"
            phx-click="delete_set"
            phx-value-id={@set.id}
            data-confirm={"Delete \"#{@set.name}\"? The meditations themselves are kept."}
            class="admin-btn admin-btn-danger"
            aria-label={"Delete #{@set.name}"}
          >
            <span class="hero-trash size-3.5" aria-hidden="true" />
          </button>
        </div>
      </td>
    </tr>

    <tr :if={@expanded} class="bg-admin-sunken">
      <td colspan="9" class="pt-0">
        <div class="pl-6 pr-2 pb-1">
          <p :if={@expanded_meditations == []} class="text-xs text-admin-ink-soft italic">
            No meditations in this set yet. Edit the set to add some.
          </p>
          <ol :if={@expanded_meditations != []} class="divide-y divide-admin-hairline">
            <li
              :for={{meditation, position} <- Enum.with_index(@expanded_meditations, 1)}
              class="flex items-center justify-between gap-3 py-1.5"
            >
              <div class="flex items-baseline gap-2 min-w-0">
                <span class="text-admin-ink-faint text-xs w-4 text-right shrink-0">
                  {position}
                </span>
                <span class="text-admin-ink truncate">
                  {meditation.mystery.name}{if meditation.title, do: " - #{meditation.title}"}
                </span>
                <span :if={meditation.author} class="text-admin-ink-faint text-xs shrink-0">
                  {meditation.author}
                </span>
                <.admin_badge :if={meditation.archived_at} tone="red">Archived</.admin_badge>
                <.admin_badge :if={meditation.audio_url in [nil, ""]} tone="amber">
                  No audio
                </.admin_badge>
              </div>
              <.link
                navigate={"/admin/meditations/#{meditation.id}/edit?return_to=/admin/meditation-sets"}
                class="text-xs text-admin-ink-soft hover:text-navy shrink-0"
              >
                Edit
              </.link>
            </li>
          </ol>
        </div>
      </td>
    </tr>
    """
  end

  attr :state, :atom, required: true

  defp artwork_badge(assigns) do
    ~H"""
    <%= case @state do %>
      <% :served -> %>
        <.admin_badge tone="green">Served</.admin_badge>
      <% :unpublishable -> %>
        <.admin_badge
          tone="amber"
          title="A painting is uploaded but it needs a description and a licence before the app is shown it."
        >
          Not served
        </.admin_badge>
      <% :missing -> %>
        <.admin_badge tone="amber" title="No painting, and no linked author portrait to fall back on.">
          None
        </.admin_badge>
    <% end %>
    """
  end

  # What the app will print under the set's name: its own byline first, then
  # whatever the meditations agree on, then the linked author's name.
  defp byline(set) do
    author_name = set |> Map.get(:author_profile) |> author_name()

    [set.author, Map.get(set, :derived_author), author_name]
    |> Enum.find(&(&1 not in [nil, ""]))
  end

  defp author_name(%{name: name}), do: name
  defp author_name(_not_loaded), do: nil

  defp default_counts do
    %{meditation_count: 0, audio_count: 0, archived_count: 0}
  end
end
