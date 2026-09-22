defmodule LumenViaeWeb.API.MeditationSetController do
  use LumenViaeWeb, :controller
  alias LumenViae.Rosary

  action_fallback LumenViaeWeb.API.FallbackController

  @doc """
  Lists all meditation sets, optionally filtered by category.
  """
  def index(conn, %{"category" => category}) do
    sets = Rosary.list_visible_meditation_sets_by_category(category)
    render(conn, :index, sets: sets)
  end

  def index(conn, _params) do
    sets = Rosary.list_visible_meditation_sets()
    render(conn, :index, sets: sets)
  end

  @doc """
  Shows a single meditation set with full details including ordered meditations and audio URLs.
  """
  def show(conn, %{"id" => id}) do
    # Result-shaped rather than the bang version, so a missing or hidden set
    # comes back through the fallback controller in the same envelope as
    # every other error instead of as a rendered exception.
    with {:ok, set} <- Rosary.fetch_visible_meditation_set(id) do
      # Fresh presigned URLs for every voice of every meditation, keyed by
      # meditation id for the JSON view
      narrations =
        Map.new(set.meditations, fn meditation ->
          {meditation.id, Rosary.sign_meditation_narrations(meditation)}
        end)

      conn
      # Every audio_url below is presigned and time-limited. Nothing in
      # between may hold a copy to serve to somebody else after it expires.
      |> put_resp_header("cache-control", "private, no-store")
      |> render(:show, set: set, narrations: narrations, audio_expires_at: audio_expiry())
    end
  end

  # The signing moment is the same for every URL in this response, so the
  # expiry is carried once on the set rather than repeated on all seven
  # meditations. A client storing this response for offline use compares it
  # to the clock to know whether the URLs it holds are still worth trying.
  defp audio_expiry do
    DateTime.utc_now()
    |> DateTime.add(Rosary.audio_url_ttl(), :second)
    |> DateTime.truncate(:second)
  end
end
