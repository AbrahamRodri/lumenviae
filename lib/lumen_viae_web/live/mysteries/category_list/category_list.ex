defmodule LumenViaeWeb.Live.Mysteries.CategoryList do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(%{"category" => category}, _session, socket) do
    if category in ["joyful", "sorrowful", "glorious", "seven_sorrows"] do
      meditation_sets = Rosary.list_meditation_sets_by_category(category)

      {:ok,
       socket
       |> assign(:category, category)
       |> assign(:meditation_sets, meditation_sets)
       |> assign(:page_title, category_title(category))}
    else
      raise LumenViaeWeb.NotFoundError, message: "unknown mystery category: #{category}"
    end
  end

  defp category_title("joyful"), do: "The Joyful Mysteries"
  defp category_title("sorrowful"), do: "The Sorrowful Mysteries"
  defp category_title("glorious"), do: "The Glorious Mysteries"
  defp category_title("seven_sorrows"), do: "The Seven Sorrows of Mary"

  defp category_days("joyful"), do: "Mondays and Thursdays"
  defp category_days("sorrowful"), do: "Tuesdays and Fridays"
  defp category_days("glorious"), do: "Wednesdays, Saturdays, and Sundays"
  defp category_days("seven_sorrows"), do: "Fridays in Lent and September 15th"

  defp category_epigraph("joyful"),
    do:
      {"Behold the handmaid of the Lord; be it done to me according to thy word.", "Luke 1:38"}

  defp category_epigraph("sorrowful"),
    do: {"Surely he hath borne our infirmities and carried our sorrows.", "Isaiah 53:4"}

  defp category_epigraph("glorious"),
    do: {"He is not here, but is risen.", "Luke 24:6"}

  defp category_epigraph("seven_sorrows"),
    do: {"And thy own soul a sword shall pierce.", "Luke 2:35"}

  defp has_audio?(set), do: Enum.any?(set.meditations, & &1.audio_url)

  def handle_event("random_set", _params, %{assigns: %{meditation_sets: []}} = socket) do
    {:noreply, socket}
  end

  def handle_event(
        "random_set",
        _params,
        %{assigns: %{meditation_sets: meditation_sets}} = socket
      ) do
    random_set = Enum.random(meditation_sets)

    {:noreply, push_navigate(socket, to: "/meditation-sets/#{random_set.id}/pray")}
  end
end
