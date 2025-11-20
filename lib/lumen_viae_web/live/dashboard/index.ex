defmodule LumenViaeWeb.Live.Dashboard.Index do
  @moduledoc """
  Dashboard - focused view for selecting and praying mysteries
  """
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  @mystery_sets [
    joyful: %{
      title: "The Joyful Mysteries",
      short_title: "Joyful",
      schedule: "Mondays & Thursdays",
      path: "/mysteries/joyful",
      icon: "✦",
      color: "gold"
    },
    sorrowful: %{
      title: "The Sorrowful Mysteries",
      short_title: "Sorrowful",
      schedule: "Tuesdays & Fridays",
      path: "/mysteries/sorrowful",
      icon: "✝",
      color: "purple"
    },
    glorious: %{
      title: "The Glorious Mysteries",
      short_title: "Glorious",
      schedule: "Wednesdays & Saturdays",
      path: "/mysteries/glorious",
      icon: "✧",
      color: "gold"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    mystery_sets = build_mystery_sets()
    meditation_sets = Rosary.list_meditation_sets()

    {:ok,
     socket
     |> assign(:page_title, "Prayer Dashboard")
     |> assign(:mystery_sets, mystery_sets)
     |> assign(:meditation_sets, meditation_sets)
     |> assign(:today, today)
     |> assign_recommended_set(today)}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset_minutes}, socket) do
    utc_now = DateTime.utc_now()
    local_datetime = DateTime.add(utc_now, -offset_minutes * 60, :second)
    local_date = DateTime.to_date(local_datetime)

    {:noreply,
     socket
     |> assign(:today, local_date)
     |> assign_recommended_set(local_date)}
  end

  defp assign_recommended_set(socket, date) do
    recommended_key = recommended_set(date)
    mystery_sets = socket.assigns.mystery_sets

    recommended_set =
      Enum.into(mystery_sets, %{}, fn {key, data} -> {key, data} end)[recommended_key]

    socket
    |> assign(:recommended_set_key, recommended_key)
    |> assign(:recommended_set, recommended_set)
  end

  defp build_mystery_sets do
    Enum.map(@mystery_sets, fn {key, attrs} -> {key, Map.put(attrs, :key, key)} end)
  end

  defp recommended_set(date) do
    case Date.day_of_week(date) do
      1 -> :joyful
      2 -> :sorrowful
      3 -> :glorious
      4 -> :joyful
      5 -> :sorrowful
      6 -> :joyful
      7 -> :glorious
    end
  end

  def meditation_sets_by_category(meditation_sets, category) do
    Enum.filter(meditation_sets, fn set -> set.category == to_string(category) end)
  end
end
