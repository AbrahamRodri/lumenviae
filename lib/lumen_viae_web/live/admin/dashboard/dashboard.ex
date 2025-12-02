defmodule LumenViaeWeb.Live.Admin.Dashboard do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:meditation_count, count_meditations())
     |> assign(:meditation_set_count, count_meditation_sets())
     |> assign(:mystery_count, count_mysteries())
     |> assign(:total_completions, count_total_completions())
     |> assign(:completions_today, count_completions_today())
     |> assign(:completions_by_set, get_completions_by_set())
     |> assign(:recent_completions, get_recent_completions())}
  end

  defp count_meditations do
    Rosary.count_meditations()
  end

  defp count_meditation_sets do
    Rosary.count_meditation_sets()
  end

  defp count_mysteries do
    Rosary.count_mysteries()
  end

  defp count_total_completions do
    Rosary.count_total_completions()
  end

  defp count_completions_today do
    Rosary.count_completions_today()
  end

  defp get_completions_by_set do
    Rosary.get_completions_by_set()
  end

  defp get_recent_completions do
    Rosary.get_recent_completions(15)
  end

  defp format_central_time(utc_datetime) do
    # Convert UTC to Central Time (UTC-6 CST or UTC-5 CDT)
    # Using DateTime.shift_zone/2 requires tzdata dependency
    # For now, we'll subtract 6 hours (standard time offset)
    central_datetime = DateTime.add(utc_datetime, -6 * 3600, :second)
    Calendar.strftime(central_datetime, "%B %d, %Y at %I:%M %p CT")
  end

  # TODO: Archived for future use when location tracking is re-enabled
  # defp format_location(completion) do
  #   parts = [completion.city, completion.region, completion.country]
  #   |> Enum.reject(&is_nil/1)
  #   |> Enum.reject(&(&1 == ""))
  #
  #   case parts do
  #     [] -> nil
  #     parts -> Enum.join(parts, ", ")
  #   end
  # end
end
