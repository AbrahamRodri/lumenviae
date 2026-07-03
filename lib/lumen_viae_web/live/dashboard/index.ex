defmodule LumenViaeWeb.Live.Dashboard.Index do
  @moduledoc """
  Prayer dashboard - a focused daily prayer companion.

  Centers on today's mysteries and lets the user enter prayer directly
  with any meditation set for the day, without intermediate pages.
  """
  use LumenViaeWeb, :live_view
  alias LumenViae.LiturgicalCalendar
  alias LumenViae.Rosary

  @mystery_sets [
    joyful: %{
      title: "The Joyful Mysteries",
      short_title: "Joyful",
      numeral: "I",
      schedule: "Mondays & Thursdays",
      path: "/mysteries/joyful",
      mysteries: [
        "The Annunciation",
        "The Visitation",
        "The Nativity of Our Lord",
        "The Presentation in the Temple",
        "The Finding of Jesus in the Temple"
      ]
    },
    sorrowful: %{
      title: "The Sorrowful Mysteries",
      short_title: "Sorrowful",
      numeral: "II",
      schedule: "Tuesdays & Fridays",
      path: "/mysteries/sorrowful",
      mysteries: [
        "The Agony in the Garden",
        "The Scourging at the Pillar",
        "The Crowning with Thorns",
        "The Carrying of the Cross",
        "The Crucifixion"
      ]
    },
    glorious: %{
      title: "The Glorious Mysteries",
      short_title: "Glorious",
      numeral: "III",
      schedule: "Wednesdays, Saturdays & Sundays",
      path: "/mysteries/glorious",
      mysteries: [
        "The Resurrection",
        "The Ascension",
        "The Descent of the Holy Ghost",
        "The Assumption of Our Lady",
        "The Coronation of Our Lady"
      ]
    }
  ]

  @seven_sorrows %{
    title: "The Seven Sorrows of Mary",
    short_title: "Seven Sorrows",
    schedule: "Fridays in Lent & September 15th",
    path: "/mysteries/seven_sorrows"
  }

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
    today = Date.utc_today()
    mystery_sets = build_mystery_sets()
    meditation_sets = Rosary.list_meditation_sets_with_meditations()

    {:ok,
     socket
     |> assign(:page_title, "Prayer Dashboard")
     |> assign(:mystery_sets, mystery_sets)
     |> assign(:meditation_sets, meditation_sets)
     |> assign(:seven_sorrows, @seven_sorrows)
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

  def handle_event("providence", _params, socket) do
    case socket.assigns.todays_meditation_sets do
      [] ->
        {:noreply, socket}

      sets ->
        chosen = Enum.random(sets)
        {:noreply, push_navigate(socket, to: "/meditation-sets/#{chosen.id}/pray")}
    end
  end

  defp assign_recommended_set(socket, date) do
    recommended_key = LiturgicalCalendar.recommended_mysteries(date)
    mystery_sets = socket.assigns.mystery_sets

    recommended_set =
      Enum.into(mystery_sets, %{}, fn {key, data} -> {key, data} end)[recommended_key]

    todays_meditation_sets =
      meditation_sets_by_category(socket.assigns.meditation_sets, recommended_key)

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
    |> assign(:todays_meditation_sets, todays_meditation_sets)
    |> assign(:week, week)
  end

  defp build_mystery_sets do
    Enum.map(@mystery_sets, fn {key, attrs} -> {key, Map.put(attrs, :key, key)} end)
  end

  def meditation_sets_by_category(meditation_sets, category) do
    Enum.filter(meditation_sets, fn set -> set.category == to_string(category) end)
  end

  defp has_audio?(set), do: Enum.any?(set.meditations, & &1.audio_url)
end
