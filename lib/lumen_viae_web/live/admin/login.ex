defmodule LumenViaeWeb.Live.Admin.Login do
  use LumenViaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, password: "", error: nil)}
  end

  @impl true
  def handle_event("validate", %{"password" => password}, socket) do
    {:noreply, assign(socket, password: password, error: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-navy-dark">
      <div class="max-w-md w-full mx-4">
        <div class="bg-cream rounded-lg shadow-xl p-8">
          <div class="text-center mb-8">
            <h1 class="font-cinzel text-3xl text-navy-dark mb-2">Admin Login</h1>
            <p class="text-navy-light">Enter password to continue</p>
          </div>

          <form action="/admin/session" method="post" class="space-y-6">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <div>
              <label for="password" class="block text-sm font-medium text-navy-dark mb-2">
                Password
              </label>
              <input
                type="password"
                name="password"
                id="password"
                class="w-full px-4 py-3 border border-navy-light rounded-md focus:outline-none focus:ring-2 focus:ring-gold focus:border-transparent"
                placeholder="Enter admin password"
                autofocus
                required
              />
            </div>

            <button
              type="submit"
              class="w-full bg-gold hover:bg-gold-dark text-navy-dark font-semibold py-3 px-4 rounded-md transition-colors duration-200"
            >
              Login
            </button>
          </form>

          <div class="mt-6 text-center">
            <a href="/" class="text-navy-light hover:text-gold text-sm transition-colors">
              Back to Home
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
