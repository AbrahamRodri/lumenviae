defmodule LumenViaeWeb.Live.Meditations.Sets.Edit.LabelsSection do
  @moduledoc """
  Labels card for the meditation set edit page.

  Shows the set's labels in priority order with move/remove controls, plus
  the remaining vocabulary as add buttons. Changes persist immediately; the
  parent Edit LiveView handles the `add_label`, `remove_label`, and
  `move_label` events.
  """
  use Phoenix.Component

  import LumenViaeWeb.Components.Admin

  attr :labels, :list, required: true
  attr :vocabulary, :list, required: true
  attr :max_labels, :integer, required: true

  def labels_section(assigns) do
    assigns =
      assigns
      |> assign(:available, Enum.reject(assigns.vocabulary, &(&1 in assigns.labels)))
      |> assign(:at_max, length(assigns.labels) >= assigns.max_labels)

    ~H"""
    <.panel
      title={"Labels (#{length(@labels)} of #{@max_labels})"}
      description="The first label is the section this set appears under in the app's picker; every label becomes a filter chip. Saved immediately."
    >
      <p :if={@labels == []} class="text-[0.8125rem] text-admin-ink-soft">
        No labels yet. Unlabelled sets appear under "More" at the end of the picker.
      </p>

      <ol :if={@labels != []} class="divide-y divide-admin-hairline">
        <li
          :for={{label, index} <- Enum.with_index(@labels)}
          class="flex items-center justify-between gap-3 py-2"
        >
          <div class="flex items-center gap-2 min-w-0">
            <span class="text-admin-ink-faint text-xs w-4 text-right shrink-0">{index + 1}</span>
            <span class="font-medium text-admin-ink">{label}</span>
            <.admin_badge :if={index == 0} tone="gold">Primary group</.admin_badge>
          </div>
          <div class="flex items-center gap-1 shrink-0">
            <button
              type="button"
              phx-click="move_label"
              phx-value-label={label}
              phx-value-direction="up"
              disabled={index == 0}
              class="admin-btn admin-btn-secondary"
              aria-label={"Move #{label} up"}
            >
              <span class="hero-arrow-up size-3.5" aria-hidden="true" />
            </button>
            <button
              type="button"
              phx-click="move_label"
              phx-value-label={label}
              phx-value-direction="down"
              disabled={index == length(@labels) - 1}
              class="admin-btn admin-btn-secondary"
              aria-label={"Move #{label} down"}
            >
              <span class="hero-arrow-down size-3.5" aria-hidden="true" />
            </button>
            <button
              type="button"
              phx-click="remove_label"
              phx-value-label={label}
              class="admin-btn admin-btn-danger"
              aria-label={"Remove #{label}"}
            >
              <span class="hero-x-mark size-3.5" aria-hidden="true" />
            </button>
          </div>
        </li>
      </ol>

      <div class="mt-4 pt-4 border-t border-admin-hairline">
        <p class="admin-eyebrow mb-2">Add a label</p>

        <p :if={@available == []} class="text-[0.8125rem] text-admin-ink-soft">
          Every available label is already applied to this set.
        </p>

        <div :if={@available != []} class="flex flex-wrap gap-2">
          <button
            :for={label <- @available}
            type="button"
            phx-click="add_label"
            phx-value-label={label}
            disabled={@at_max}
            class="admin-btn admin-btn-secondary"
          >
            <span class="hero-plus size-3.5" aria-hidden="true" />{label}
          </button>
        </div>

        <p :if={@at_max and @available != []} class="text-xs text-admin-ink-faint mt-2">
          Maximum of {@max_labels} labels reached. Remove one to add another.
        </p>
      </div>
    </.panel>
    """
  end
end
