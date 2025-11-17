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
    Rosary.count_meditations()
  end

  defp count_meditation_sets do
    Rosary.count_meditation_sets()
  end

  defp count_mysteries do
    Rosary.count_mysteries()
  end
end
