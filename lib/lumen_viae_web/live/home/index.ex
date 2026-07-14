defmodule LumenViaeWeb.Live.Home.Index do
  @moduledoc """
  Home page - displays welcome message and mystery categories
  """
  use LumenViaeWeb, :live_view
  alias LumenViae.LiturgicalCalendar

  @mystery_sets [
    joyful: %{
      title: "The Joyful Mysteries",
      short_title: "Joyful",
      numeral: "I",
      schedule: "Mondays and Thursdays (and Sundays in Advent)",
      description:
        "Contemplate the joyful events of Christ's early life and the Blessed Virgin's faithful yes to God's will.",
      mysteries: [
        "The Annunciation",
        "The Visitation",
        "The Nativity of Our Lord",
        "The Presentation in the Temple",
        "The Finding of Jesus in the Temple"
      ],
      fruit: "Humility, charity, poverty of spirit, obedience, and piety",
      path: "/mysteries/joyful"
    },
    sorrowful: %{
      title: "The Sorrowful Mysteries",
      short_title: "Sorrowful",
      numeral: "II",
      schedule: "Tuesdays and Fridays (and Sundays in Lent)",
      description:
        "Meditate on Our Lord's passion and suffering, offered for the redemption of mankind.",
      mysteries: [
        "The Agony in the Garden",
        "The Scourging at the Pillar",
        "The Crowning with Thorns",
        "The Carrying of the Cross",
        "The Crucifixion"
      ],
      fruit: "Contrition, mortification, patience, and conformity to the will of God",
      path: "/mysteries/sorrowful"
    },
    glorious: %{
      title: "The Glorious Mysteries",
      short_title: "Glorious",
      numeral: "III",
      schedule: "Wednesdays, Saturdays (and Sundays through the year)",
      description:
        "Rejoice in the triumph of Christ's resurrection and the glory of His Most Holy Mother.",
      mysteries: [
        "The Resurrection",
        "The Ascension",
        "The Descent of the Holy Ghost",
        "The Assumption of Our Lady",
        "The Coronation of Our Lady"
      ],
      fruit: "Faith, hope, devotion to Mary, and the grace of a happy death",
      path: "/mysteries/glorious"
    }
  ]

  @week_days [
    {1, "Mon"},
    {2, "Tue"},
    {3, "Wed"},
    {4, "Thu"},
    {5, "Fri"},
    {6, "Sat"},
    {7, "Sun"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    # Start with UTC as fallback until we get user's timezone
    today = Date.utc_today()
    mystery_sets = build_mystery_sets()

    {:ok,
     socket
     |> assign(:page_title, "Meditations on the Holy Rosary")
     |> assign(
       :meta_description,
       "Pray the traditional fifteen mysteries of the Holy Rosary with meditations from the saints and doctors of the Church. Daily mysteries, guided audio, and the methods of St. Louis de Montfort."
     )
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
    recommended_key = LiturgicalCalendar.recommended_mysteries(date)
    mystery_sets = socket.assigns.mystery_sets

    recommended_set =
      Enum.into(mystery_sets, %{}, fn {key, data} -> {key, data} end)[recommended_key]

    week =
      Enum.map(@week_days, fn {dow, label} ->
        day_date = Date.add(date, dow - Date.day_of_week(date))

        %{
          label: label,
          key: LiturgicalCalendar.recommended_mysteries(day_date),
          today?: dow == Date.day_of_week(date)
        }
      end)

    socket
    |> assign(:recommended_set_key, recommended_key)
    |> assign(:recommended_set, recommended_set)
    |> assign(:week, week)
  end

  defp build_mystery_sets do
    Enum.map(@mystery_sets, fn {key, attrs} -> {key, Map.put(attrs, :key, key)} end)
  end
end
