defmodule LumenViaeWeb.Live.MysterySet.List do
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

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-cream">
      <div class="max-w-5xl mx-auto px-8 py-12">
        <!-- Category Header -->
        <div class="text-center mb-12">
          <h2 class="font-cinzel text-4xl text-navy mb-3">
            <%= category_title(@category) %>
          </h2>
          <p class="font-crimson text-gray-600 italic text-lg">
            <%= category_days(@category) %>
          </p>
        </div>

        <!-- Meditation Sets -->
        <div class="space-y-6">
          <%= if @meditation_sets == [] do %>
            <div class="bg-white border-l-4 border-gold p-12 text-center">
              <p class="font-crimson text-gray-600 text-lg mb-6">
                No meditation sets available yet for <%= category_title(@category) %>.
              </p>
              <p class="font-crimson text-gray-500 text-sm">
                Meditation sets will appear here once they are created through the admin interface.
              </p>
            </div>
          <% else %>
            <%= for set <- @meditation_sets do %>
              <.link
                navigate={"/meditation-sets/#{set.id}/pray"}
                class="block bg-white border-l-4 border-gold p-8 hover:shadow-lg transition-shadow"
              >
                <h3 class="font-cinzel text-2xl text-navy mb-2">
                  <%= set.name %>
                </h3>
                <%= if set.description do %>
                  <p class="font-crimson text-gray-600 mt-3">
                    <%= set.description %>
                  </p>
                <% end %>
                <div class="mt-4 font-crimson text-gold text-sm">
                  Begin Prayer →
                </div>
              </.link>
            <% end %>
          <% end %>
        </div>

        <!-- Back to Home -->
        <div class="mt-12 text-center">
          <.link
            navigate="/"
            class="inline-block font-crimson text-navy hover:text-gold transition-colors"
          >
            ← Return to All Mysteries
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
