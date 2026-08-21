defmodule LumenViaeWeb.Live.Mysteries.CategoryList do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(%{"category" => category}, _session, socket) do
    if category in ["joyful", "sorrowful", "glorious", "luminous", "seven_sorrows"] do
      meditation_sets = Rosary.list_visible_meditation_sets_by_category(category)

      {:ok,
       socket
       |> assign(:category, category)
       |> assign(:meditation_sets, meditation_sets)
       |> assign(:page_title, category_title(category))
       |> assign(:meta_description, category_description(category))}
    else
      raise LumenViaeWeb.NotFoundError, message: "unknown mystery category: #{category}"
    end
  end

  defp category_title("joyful"), do: "The Joyful Mysteries"
  defp category_title("sorrowful"), do: "The Sorrowful Mysteries"
  defp category_title("glorious"), do: "The Glorious Mysteries"
  defp category_title("luminous"), do: "The Luminous Mysteries"
  defp category_title("seven_sorrows"), do: "The Seven Sorrows of Mary"

  defp category_description("joyful"),
    do:
      "Pray the Joyful Mysteries with meditations from the saints: the Annunciation, Visitation, Nativity, Presentation, and Finding in the Temple, with guided audio."

  defp category_description("sorrowful"),
    do:
      "Pray the Sorrowful Mysteries with meditations from the saints: the Agony in the Garden, Scourging, Crowning with Thorns, Carrying of the Cross, and Crucifixion, with guided audio."

  defp category_description("glorious"),
    do:
      "Pray the Glorious Mysteries with meditations from the saints: the Resurrection, Ascension, Descent of the Holy Ghost, Assumption, and Coronation of Our Lady, with guided audio."

  defp category_description("luminous"),
    do:
      "Pray the Luminous Mysteries with meditations from the saints: the Baptism of Our Lord, the wedding at Cana, the proclamation of the Kingdom, the Transfiguration, and the institution of the Eucharist."

  defp category_description("seven_sorrows"),
    do:
      "Pray the Seven Sorrows of Mary with meditations from the saints, from the prophecy of Simeon to the burial of Our Lord, with guided audio."

  defp category_days("joyful"), do: "Mondays and Thursdays"
  defp category_days("sorrowful"), do: "Tuesdays and Fridays"
  defp category_days("glorious"), do: "Wednesdays, Saturdays, and Sundays"
  defp category_days("luminous"), do: "Thursdays in the modern schedule"
  defp category_days("seven_sorrows"), do: "Fridays in Lent and September 15th"

  defp category_epigraph("joyful"),
    do: {"Behold the handmaid of the Lord; be it done to me according to thy word.", "Luke 1:38"}

  defp category_epigraph("sorrowful"),
    do: {"Surely he hath borne our infirmities and carried our sorrows.", "Isaiah 53:4"}

  defp category_epigraph("glorious"),
    do: {"He is not here, but is risen.", "Luke 24:6"}

  defp category_epigraph("luminous"),
    do: {"This is my beloved Son, in whom I am well pleased: hear ye him.", "Matthew 17:5"}

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
