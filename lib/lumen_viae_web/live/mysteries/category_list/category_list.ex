defmodule LumenViaeWeb.Live.Mysteries.CategoryList do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(%{"category" => category}, _session, socket) do
    if category in ["joyful", "sorrowful", "glorious"] do
      meditation_sets = Rosary.list_meditation_sets_by_category(category)

      {:ok,
       socket
       |> assign(:category, category)
       |> assign(:meditation_sets, meditation_sets)
       |> assign(:page_title, category_title(category))}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  defp category_title("joyful"), do: "The Joyful Mysteries"
  defp category_title("sorrowful"), do: "The Sorrowful Mysteries"
  defp category_title("glorious"), do: "The Glorious Mysteries"

  defp category_days("joyful"), do: "Mondays, Thursdays, and Saturdays"
  defp category_days("sorrowful"), do: "Tuesdays and Fridays"
  defp category_days("glorious"), do: "Wednesdays, Thursdays, and Sundays"

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
