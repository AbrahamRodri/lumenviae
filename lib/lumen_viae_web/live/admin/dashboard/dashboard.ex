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
    Rosary.get_recent_completions(5)
  end
end
