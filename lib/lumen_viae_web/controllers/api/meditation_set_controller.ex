defmodule LumenViaeWeb.API.MeditationSetController do
  use LumenViaeWeb, :controller
  alias LumenViae.Rosary

  action_fallback LumenViaeWeb.API.FallbackController

  @doc """
  Lists all meditation sets, optionally filtered by category.
  """
  def index(conn, %{"category" => category}) do
    sets = Rosary.list_meditation_sets_by_category(category)
    render(conn, :index, sets: sets)
  end

  def index(conn, _params) do
    sets = Rosary.list_meditation_sets()
    render(conn, :index, sets: sets)
  end

  @doc """
  Shows a single meditation set with full details including ordered meditations and audio URLs.
  """
  def show(conn, %{"id" => id}) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(id)

    # Generate fresh pre-signed S3 URLs for all meditations
    meditations_with_audio =
      Enum.map(set.meditations, fn meditation ->
        audio_url = Rosary.get_meditation_audio_url(meditation)
        %{meditation | audio_url: audio_url}
      end)

    set_with_audio = %{set | meditations: meditations_with_audio}
    render(conn, :show, set: set_with_audio)
  end
end
