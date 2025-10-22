defmodule LumenViaeWeb.HomeLive do
  use LumenViaeWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-cream">
      <!-- Hero Section -->
      <div class="bg-white border-b-2 border-gold py-16 px-8">
        <div class="max-w-4xl mx-auto text-center">
          <h2 class="font-cinzel text-4xl text-navy mb-4">
            Meditations on the Holy Rosary
          </h2>
          <p class="font-crimson text-lg text-gray-600 max-w-2xl mx-auto">
            Enter into contemplation of the sacred mysteries through the meditations of the saints and doctors of the Church.
          </p>
        </div>
      </div>

      <!-- Mystery Categories -->
      <div class="max-w-5xl mx-auto px-8 py-16">
        <div class="grid md:grid-cols-3 gap-8">
          <!-- Joyful Mysteries -->
          <.link
            navigate="/joyful"
            class="block bg-white border-l-4 border-gold p-8 hover:shadow-lg transition-shadow"
          >
            <h3 class="font-cinzel text-2xl text-navy mb-3">
              The Joyful Mysteries
            </h3>
            <p class="font-crimson text-gray-600 mb-4 italic">
              Mondays, Thursdays, and Saturdays
            </p>
            <p class="font-crimson text-gray-700 text-sm">
              Contemplate the joyful events of Christ's early life and the Blessed Virgin's faithful yes to God's will.
            </p>
          </.link>

          <!-- Sorrowful Mysteries -->
          <.link
            navigate="/sorrowful"
            class="block bg-white border-l-4 border-gold p-8 hover:shadow-lg transition-shadow"
          >
            <h3 class="font-cinzel text-2xl text-navy mb-3">
              The Sorrowful Mysteries
            </h3>
            <p class="font-crimson text-gray-600 mb-4 italic">
              Tuesdays and Fridays
            </p>
            <p class="font-crimson text-gray-700 text-sm">
              Meditate on Our Lord's passion and suffering, offered for the redemption of mankind.
            </p>
          </.link>

          <!-- Glorious Mysteries -->
          <.link
            navigate="/glorious"
            class="block bg-white border-l-4 border-gold p-8 hover:shadow-lg transition-shadow"
          >
            <h3 class="font-cinzel text-2xl text-navy mb-3">
              The Glorious Mysteries
            </h3>
            <p class="font-crimson text-gray-600 mb-4 italic">
              Wednesdays, Thursdays, and Sundays
            </p>
            <p class="font-crimson text-gray-700 text-sm">
              Rejoice in the triumph of Christ's resurrection and the glory of His Mother.
            </p>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
