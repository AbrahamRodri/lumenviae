defmodule LumenViaeWeb.Live.Home.Index do
  @moduledoc """
  Home page - displays welcome message and mystery categories
  """
  use LumenViaeWeb, :live_view

  @mystery_sets [
    joyful: %{
      title: "The Joyful Mysteries",
      schedule: "Mondays and Saturdays (and Sundays in Advent)",
      description:
        "Contemplate the joyful events of Christ's early life and the Blessed Virgin's faithful yes to God's will.",
      path: "/mysteries/joyful"
    },
    sorrowful: %{
      title: "The Sorrowful Mysteries",
      schedule: "Tuesdays and Fridays (and Sundays in Lent)",
      description:
        "Meditate on Our Lord's passion and suffering, offered for the redemption of mankind.",
      path: "/mysteries/sorrowful"
    },
    glorious: %{
      title: "The Glorious Mysteries",
      schedule: "Wednesdays and Sundays (Ordinary Time)",
      description:
        "Rejoice in the triumph of Christ's resurrection and the glory of His Most Holy Mother.",
      path: "/mysteries/glorious"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    # Start with UTC as fallback until we get user's timezone
    today = Date.utc_today()
    mystery_sets = build_mystery_sets()

    {:ok,
     socket
     |> assign(:mystery_sets, mystery_sets)
     |> assign(:today, today)
     |> assign_recommended_set(today)}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset_minutes}, socket) do
    # Calculate user's local date from UTC
    # offset_minutes is negative for timezones ahead of UTC (e.g., -180 for UTC-3 Argentina)
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
      # Monday - Joyful
      1 -> :joyful
      # Tuesday - Sorrowful
      2 -> :sorrowful
      # Wednesday - Glorious
      3 -> :glorious
      # Thursday - Joyful (traditionally, some sources say Joyful, others Glorious)
      4 -> :joyful
      # Friday - Sorrowful
      5 -> :sorrowful
      # Saturday - Joyful
      6 -> :joyful
      # Sunday - Glorious (Ordinary Time), Sorrowful (Lent), Joyful (Advent)
      # For now, defaulting to Glorious until liturgical calendar is implemented
      7 -> :glorious
    end
  end
end
