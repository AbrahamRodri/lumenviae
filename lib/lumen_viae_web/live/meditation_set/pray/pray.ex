defmodule LumenViaeWeb.Live.MeditationSet.Pray do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(%{"set_id" => set_id}, _session, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

    if set do
      {:ok,
       socket
       |> assign(:set, set)
       |> assign(:current_index, 0)
       |> assign(:page_title, set.name)}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  def handle_event("next", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)

    new_index = min(current + 1, total - 1)
    {:noreply, assign(socket, :current_index, new_index)}
  end

  def handle_event("previous", _params, socket) do
    current = socket.assigns.current_index
    new_index = max(current - 1, 0)
    {:noreply, assign(socket, :current_index, new_index)}
  end

  defp current_meditation(assigns) do
    Enum.at(assigns.set.meditations, assigns.current_index)
  end

  def render(assigns) do
    meditation = current_meditation(assigns)
    total_count = length(assigns.set.meditations)

    assigns =
      assigns
      |> assign(:meditation, meditation)
      |> assign(:total_count, total_count)

    ~H"""
    <div class="min-h-screen bg-cream pb-16">
      <div class="max-w-4xl mx-auto px-8 py-12" id="meditation-container" phx-hook="ScrollToTop">
        <!-- Progress Indicator -->
        <div class="text-center mb-8">
          <p class="font-crimson text-gray-600 mb-2">
            {@set.name}
          </p>
          <div class="flex justify-center items-center gap-2">
            <%= for i <- 0..(@total_count - 1) do %>
              <div class={"w-3 h-3 rounded-full #{if i == @current_index, do: "bg-gold", else: "bg-gray-300"}"}>
              </div>
            <% end %>
          </div>
          <p class="font-crimson text-sm text-gray-500 mt-2">
            {@current_index + 1} of {@total_count}
          </p>
        </div>
        
    <!-- Mystery and Meditation -->
        <div class="bg-white border-l-4 border-gold p-12 mb-8">
          <!-- Mystery Title -->
          <h2 class="font-cinzel text-3xl text-navy mb-2 text-center">
            {@meditation.mystery.name}
          </h2>

          <%= if @meditation.mystery.scripture_reference do %>
            <p class="font-crimson text-gray-500 italic text-center mb-8">
              {@meditation.mystery.scripture_reference}
            </p>
          <% end %>
          
    <!-- Mystery Description -->
          <%= if @meditation.mystery.description do %>
            <p class="font-crimson text-gray-600 text-center mb-8 pb-8 border-b border-gray-200">
              {@meditation.mystery.description}
            </p>
          <% end %>
          
    <!-- Meditation Content -->
          <%= if @meditation.title do %>
            <h3 class="font-cinzel text-xl text-navy mb-4 mt-8">
              {@meditation.title}
            </h3>
          <% end %>

          <div class="font-crimson text-gray-700 text-lg leading-relaxed whitespace-pre-wrap">
            {@meditation.content}
          </div>
          
    <!-- Attribution -->
          <%= if @meditation.author || @meditation.source do %>
            <div class="mt-8 pt-6 border-t border-gray-200 text-right">
              <p class="font-crimson text-gray-500 italic text-sm">
                <%= if @meditation.author do %>
                  — {@meditation.author}
                <% end %>
                <%= if @meditation.source do %>
                  <span class="block mt-1">{@meditation.source}</span>
                <% end %>
              </p>
            </div>
          <% end %>
        </div>
        
    <!-- Navigation Controls -->
        <div class="flex justify-between items-center">
          <button
            phx-click="previous"
            disabled={@current_index == 0}
            class="font-cinzel px-6 py-3 bg-navy text-gold border-2 border-gold hover:bg-gold hover:text-navy transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
          >
            ← Previous Mystery
          </button>

          <%= if @current_index == @total_count - 1 do %>
            <.link
              navigate={"/mysteries/" <> @set.category}
              class="font-cinzel px-6 py-3 bg-gold text-navy border-2 border-gold hover:bg-navy hover:text-gold transition-colors"
            >
              Complete Rosary
            </.link>
          <% else %>
            <button
              phx-click="next"
              class="font-cinzel px-6 py-3 bg-gold text-navy border-2 border-gold hover:bg-navy hover:text-gold transition-colors"
            >
              Next Mystery →
            </button>
          <% end %>
        </div>
        
    <!-- Exit to Category -->
        <div class="mt-8 text-center">
          <.link
            navigate={"/" <> @set.category}
            class="font-crimson text-navy hover:text-gold transition-colors text-sm"
          >
            Exit to {String.capitalize(@set.category)} Mysteries
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
