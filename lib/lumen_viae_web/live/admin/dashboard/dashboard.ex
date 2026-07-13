defmodule LumenViaeWeb.Live.Admin.Dashboard do
  use LumenViaeWeb, :live_view

  alias LumenViae.Meditations.SetFiltering
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    sets = Rosary.list_meditation_sets()
    hidden_ids = Rosary.hidden_meditation_set_ids()
    set_stats = Rosary.meditation_set_stats()
    mysteries = Rosary.list_mysteries()
    mystery_counts = Rosary.meditation_counts_by_mystery()

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:meditation_count, Rosary.count_meditations())
     |> assign(:archived_count, Rosary.count_archived_meditations())
     |> assign(:meditation_set_count, length(sets))
     |> assign(:hidden_set_count, MapSet.size(hidden_ids))
     |> assign(:mystery_count, length(mysteries))
     |> assign(
       :health_items,
       build_health_items(sets, hidden_ids, set_stats, mysteries, mystery_counts)
     )
     |> assign(:total_completions, Rosary.count_total_completions())
     |> assign(:completions_today, Rosary.count_completions_today())
     |> assign(:completions_7_days, Rosary.count_completions_last_days(7))
     |> assign(:completions_30_days, Rosary.count_completions_last_days(30))
     |> assign(:completions_by_set, Rosary.get_completions_by_set())
     |> assign(:recent_completions, Rosary.get_recent_completions(15))}
  end

  # Each health item deep-links to the matching pre-filtered admin list, so
  # every problem the dashboard surfaces is one click from being worked on.
  defp build_health_items(sets, hidden_ids, set_stats, mysteries, mystery_counts) do
    hidden_sets = Enum.filter(sets, &MapSet.member?(hidden_ids, &1.id))
    empty_sets = Enum.filter(sets, &(SetFiltering.meditation_count(&1, set_stats) == 0))

    partial_sets =
      Enum.filter(sets, fn set ->
        count = SetFiltering.meditation_count(set, set_stats)
        count > 0 and count != SetFiltering.expected_meditation_count(set.category)
      end)

    bare_mysteries = Enum.filter(mysteries, &(Map.get(mystery_counts, &1.id, 0) == 0))

    [
      %{
        count: Rosary.count_active_meditations_missing_audio(),
        label: "Meditations missing audio",
        description: "Active meditations without a generated audio file.",
        link: "/admin/meditations?audio=without&status=active",
        names: []
      },
      %{
        count: Rosary.count_meditations_not_in_any_set(),
        label: "Meditations not in any set",
        description: "Meditations that never appear in the app or on the site.",
        link: "/admin/meditations?set=none",
        names: []
      },
      %{
        count: Rosary.count_archived_meditations(),
        label: "Archived meditations",
        description: "Hidden from all public surfaces along with their sets.",
        link: "/admin/meditations?status=archived",
        names: []
      },
      %{
        count: length(hidden_sets),
        label: "Sets hidden from public",
        description: "Contain at least one archived meditation.",
        link: "/admin/meditation-sets?visibility=hidden",
        names: Enum.map(hidden_sets, & &1.name)
      },
      %{
        count: length(empty_sets),
        label: "Empty sets",
        description: "Sets with no meditations at all.",
        link: "/admin/meditation-sets?completeness=empty",
        names: Enum.map(empty_sets, & &1.name)
      },
      %{
        count: length(partial_sets),
        label: "Partially filled sets",
        description: "Sets with the wrong meditation count for their category.",
        link: "/admin/meditation-sets?completeness=incomplete",
        names: Enum.map(partial_sets, & &1.name)
      },
      %{
        count: length(bare_mysteries),
        label: "Mysteries without meditations",
        description: "No meditation has been written for these mysteries yet.",
        link: "/admin/mysteries",
        names: Enum.map(bare_mysteries, & &1.name)
      }
    ]
  end

  defp issues?(health_items) do
    Enum.any?(health_items, &(&1.count > 0))
  end

  defp format_central_time(utc_datetime) do
    # Convert UTC to Central Time (UTC-6 CST or UTC-5 CDT)
    # Using DateTime.shift_zone/2 requires tzdata dependency
    # For now, we'll subtract 6 hours (standard time offset)
    central_datetime = DateTime.add(utc_datetime, -6 * 3600, :second)
    Calendar.strftime(central_datetime, "%B %d, %Y at %I:%M %p CT")
  end

  attr :item, :map, required: true

  defp health_item(assigns) do
    ~H"""
    <div class="flex items-start justify-between gap-4 border-b border-gray-200 py-3 last:border-b-0">
      <div class="flex items-start gap-3 min-w-0">
        <span class={[
          "font-crimson font-bold text-lg w-8 text-right flex-shrink-0",
          if(@item.count > 0, do: "text-amber-700", else: "text-green-700")
        ]}>
          {@item.count}
        </span>
        <div class="min-w-0">
          <p class="font-crimson text-navy font-semibold">{@item.label}</p>
          <p class="font-crimson text-sm text-gray-600">{@item.description}</p>
          <%= if @item.count > 0 and @item.names != [] do %>
            <p class="font-crimson text-sm text-gray-500 italic mt-1">
              {names_preview(@item.names)}
            </p>
          <% end %>
        </div>
      </div>
      <%= if @item.count > 0 do %>
        <.link
          navigate={@item.link}
          class="px-3 py-1.5 text-navy border border-navy rounded hover:bg-navy hover:text-white transition-colors font-crimson text-sm flex-shrink-0"
        >
          Review
        </.link>
      <% end %>
    </div>
    """
  end

  defp names_preview(names) do
    shown = Enum.take(names, 5)
    rest = length(names) - length(shown)

    preview = Enum.join(shown, ", ")

    if rest > 0 do
      "#{preview}, and #{rest} more"
    else
      preview
    end
  end
end
