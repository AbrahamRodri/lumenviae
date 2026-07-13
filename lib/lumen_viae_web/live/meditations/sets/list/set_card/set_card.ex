defmodule LumenViaeWeb.Live.Meditations.Sets.List.SetCard do
  @moduledoc """
  A single meditation set card in the admin sets list, with health badges
  and an inline expansion showing the set's ordered meditations. Stateless;
  events are handled by the parent LiveView.
  """
  use LumenViaeWeb, :html

  alias LumenViae.Constants
  alias LumenViae.Meditations.SetFiltering

  attr :set, :map, required: true
  attr :stats, :map, required: true
  attr :hidden, :boolean, default: false
  attr :expanded, :boolean, default: false
  attr :expanded_meditations, :list, default: []

  def set_card(assigns) do
    assigns =
      assigns
      |> assign(:counts, Map.get(assigns.stats, assigns.set.id, default_counts()))
      |> assign(:expected, SetFiltering.expected_meditation_count(assigns.set.category))

    ~H"""
    <div class="border border-gray-200 rounded-lg bg-gray-50 overflow-hidden">
      <div class="p-6">
        <div class="flex items-start justify-between gap-4">
          <div class="flex-1 min-w-0">
            <h4 class="font-cinzel text-xl text-navy">
              {@set.name}
              <%= if @hidden do %>
                <.admin_badge
                  tone="gray"
                  title="This set contains archived meditations, so it is not shown on the public site or in the app."
                >
                  Hidden from public
                </.admin_badge>
              <% end %>
            </h4>

            <div class="flex flex-wrap items-center gap-1.5 mt-2">
              <.admin_badge tone="navy">
                {Constants.mystery_category_label(@set.category)}
              </.admin_badge>

              <%= for label <- @set.labels do %>
                <.admin_badge tone="gold">{label}</.admin_badge>
              <% end %>
              <%= if @set.labels == [] do %>
                <.admin_badge
                  tone="amber"
                  title={"No labels yet - shown under \"More\" in the app picker"}
                >
                  No labels
                </.admin_badge>
              <% end %>

              <.meditation_count_badge counts={@counts} expected={@expected} />
              <.audio_badge counts={@counts} />

              <span class="font-crimson text-xs text-gray-400 ml-1">
                ID {@set.id} &middot; created {Calendar.strftime(@set.inserted_at, "%b %d, %Y")}
              </span>
            </div>

            <%= if @set.description do %>
              <p class="font-crimson text-gray-700 mt-3">{@set.description}</p>
            <% end %>
          </div>

          <div class="flex items-center gap-2 flex-shrink-0">
            <button
              phx-click="toggle_expand"
              phx-value-id={@set.id}
              class="px-3 py-1.5 text-navy border border-navy rounded hover:bg-navy hover:text-white transition-colors font-crimson text-sm"
            >
              {if @expanded, do: "Hide meditations", else: "View meditations"}
            </button>

            <.link
              navigate={"/admin/meditation-sets/#{@set.id}/edit"}
              class="px-3 py-1.5 text-navy border border-navy rounded hover:bg-navy hover:text-white transition-colors font-crimson text-sm"
            >
              Edit
            </.link>

            <button
              phx-click="delete_set"
              phx-value-id={@set.id}
              data-confirm="Are you sure you want to delete this meditation set? The meditations themselves are kept."
              class="px-3 py-1.5 text-red-600 border border-red-600 rounded hover:bg-red-600 hover:text-white transition-colors font-crimson text-sm"
            >
              Delete
            </button>
          </div>
        </div>
      </div>

      <%= if @expanded do %>
        <div class="px-6 pb-6 pt-4 bg-white border-t border-gray-200">
          <%= if @expanded_meditations == [] do %>
            <p class="font-crimson text-gray-600 text-sm italic">
              No meditations in this set yet. Edit the set to add meditations.
            </p>
          <% else %>
            <div class="space-y-2">
              <%= for {meditation, position} <- Enum.with_index(@expanded_meditations, 1) do %>
                <div class="flex items-center justify-between bg-cream p-3 rounded">
                  <div class="flex items-center gap-3 min-w-0">
                    <span class="font-cinzel text-gold text-sm w-5 text-right flex-shrink-0">
                      {position}.
                    </span>
                    <div class="min-w-0">
                      <span class="font-crimson text-navy">
                        {meditation.mystery.name}
                        {if meditation.title, do: " - #{meditation.title}"}
                      </span>
                      <%= if meditation.author do %>
                        <span class="font-crimson text-sm text-gray-500 ml-2">
                          by {meditation.author}
                        </span>
                      <% end %>
                      <%= if meditation.archived_at do %>
                        <.admin_badge tone="gray">Archived</.admin_badge>
                      <% end %>
                      <%= if meditation.audio_url in [nil, ""] do %>
                        <.admin_badge tone="amber">No audio</.admin_badge>
                      <% end %>
                    </div>
                  </div>
                  <.link
                    navigate={"/admin/meditations/#{meditation.id}/edit?return_to=/admin/meditation-sets"}
                    class="text-navy hover:text-gold font-crimson text-sm transition-colors flex-shrink-0 ml-3"
                  >
                    Edit
                  </.link>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp meditation_count_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% @counts.meditation_count == 0 -> %>
        <.admin_badge tone="amber">Empty</.admin_badge>
      <% @counts.meditation_count == @expected -> %>
        <.admin_badge tone="green">{@counts.meditation_count} meditations</.admin_badge>
      <% true -> %>
        <.admin_badge tone="amber" title={"Expected #{@expected} meditations for this category"}>
          {@counts.meditation_count} of {@expected} meditations
        </.admin_badge>
    <% end %>
    """
  end

  defp audio_badge(assigns) do
    ~H"""
    <%= if @counts.meditation_count > 0 do %>
      <%= if @counts.audio_count == @counts.meditation_count do %>
        <.admin_badge tone="green">All audio</.admin_badge>
      <% else %>
        <.admin_badge tone="amber">
          {@counts.meditation_count - @counts.audio_count} missing audio
        </.admin_badge>
      <% end %>
    <% end %>
    """
  end

  defp default_counts do
    %{meditation_count: 0, audio_count: 0, archived_count: 0}
  end
end
