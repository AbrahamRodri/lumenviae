defmodule LumenViaeWeb.Live.Meditations.Sets.Edit.LabelsSection do
  @moduledoc """
  Labels card for the meditation set edit page.

  Shows the set's labels in priority order with move/remove controls, plus
  the remaining vocabulary as add buttons. Changes persist immediately; the
  parent Edit LiveView handles the `add_label`, `remove_label`, and
  `move_label` events.
  """
  use Phoenix.Component

  attr :labels, :list, required: true
  attr :vocabulary, :list, required: true
  attr :max_labels, :integer, required: true

  def labels_section(assigns) do
    assigns =
      assigns
      |> assign(:available, Enum.reject(assigns.vocabulary, &(&1 in assigns.labels)))
      |> assign(:at_max, length(assigns.labels) >= assigns.max_labels)

    ~H"""
    <div class="bg-white border-l-4 border-gold p-8 mb-8">
      <h3 class="font-cinzel text-2xl text-navy mb-2">Labels</h3>
      <p class="font-crimson text-gray-600 text-sm mb-6">
        Labels drive the iOS meditation picker. The first label is the section this set
        appears under when browsing, and every label becomes a filter chip. Use one to {@max_labels} labels, primary group first. Changes save immediately.
      </p>

      <div class="mb-8">
        <h4 class="font-cinzel text-lg text-navy mb-3">
          Current Labels ({length(@labels)}/{@max_labels})
        </h4>
        <%= if @labels == [] do %>
          <p class="font-crimson text-gray-600 text-sm italic">
            No labels yet. Unlabeled sets appear under "More" at the end of the picker.
          </p>
        <% else %>
          <div class="space-y-2">
            <%= for {label, index} <- Enum.with_index(@labels) do %>
              <div class="flex justify-between items-center bg-cream p-3 rounded">
                <div class="flex items-center gap-3">
                  <span class="font-cinzel text-gold w-5 text-right">{index + 1}.</span>
                  <span class="font-crimson text-navy font-semibold">{label}</span>
                  <%= if index == 0 do %>
                    <span class="font-crimson text-xs text-gray-500 uppercase tracking-wide">
                      Primary group
                    </span>
                  <% end %>
                </div>
                <div class="flex items-center gap-2">
                  <button
                    type="button"
                    phx-click="move_label"
                    phx-value-label={label}
                    phx-value-direction="up"
                    disabled={index == 0}
                    class="px-3 py-1 text-navy border border-navy rounded hover:bg-navy hover:text-white transition-colors font-crimson text-sm disabled:opacity-30 disabled:pointer-events-none"
                  >
                    Up
                  </button>
                  <button
                    type="button"
                    phx-click="move_label"
                    phx-value-label={label}
                    phx-value-direction="down"
                    disabled={index == length(@labels) - 1}
                    class="px-3 py-1 text-navy border border-navy rounded hover:bg-navy hover:text-white transition-colors font-crimson text-sm disabled:opacity-30 disabled:pointer-events-none"
                  >
                    Down
                  </button>
                  <button
                    type="button"
                    phx-click="remove_label"
                    phx-value-label={label}
                    class="px-3 py-1 text-red-600 border border-red-600 rounded hover:bg-red-600 hover:text-white transition-colors font-crimson text-sm"
                  >
                    Remove
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <div>
        <h4 class="font-cinzel text-lg text-navy mb-3">Add a Label</h4>
        <%= if @available == [] do %>
          <p class="font-crimson text-gray-600 text-sm italic">
            All available labels are already applied to this set.
          </p>
        <% else %>
          <div class="flex flex-wrap gap-2">
            <%= for label <- @available do %>
              <button
                type="button"
                phx-click="add_label"
                phx-value-label={label}
                disabled={@at_max}
                class="px-4 py-2 text-navy border border-gray-300 rounded hover:border-gold hover:bg-gold hover:text-navy transition-colors font-crimson text-sm disabled:opacity-30 disabled:pointer-events-none"
              >
                {label}
              </button>
            <% end %>
          </div>
          <%= if @at_max do %>
            <p class="font-crimson text-gray-500 text-xs mt-3">
              Maximum of {@max_labels} labels reached. Remove one to add another.
            </p>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
