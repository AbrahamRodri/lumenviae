defmodule LumenViaeWeb.Live.Admin.Dashboard do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:meditation_count, count_meditations())
     |> assign(:meditation_set_count, count_meditation_sets())
     |> assign(:mystery_count, count_mysteries())}
  end

  defp count_meditations do
    length(Rosary.list_meditations())
  end

  defp count_meditation_sets do
    length(Rosary.list_meditation_sets())
  end

  defp count_mysteries do
    length(Rosary.list_mysteries())
  end
end
