defmodule LumenViaeWeb.API.MeditationSetJSON do
  alias LumenViae.Rosary.MeditationSet

  @doc """
  Renders a list of meditation sets (summary view).
  """
  def index(%{sets: sets}) do
    %{data: Enum.map(sets, &set_summary/1)}
  end

  @doc """
  Renders a single meditation set with full details.
  """
  def show(%{set: set}) do
    %{data: set_detail(set)}
  end

  defp set_summary(%MeditationSet{} = set) do
    %{
      id: set.id,
      name: set.name,
      category: set.category,
      description: set.description
    }
  end

  defp set_detail(%MeditationSet{} = set) do
    %{
      id: set.id,
      name: set.name,
      category: set.category,
      description: set.description,
      meditations: Enum.map(set.meditations, &LumenViaeWeb.API.MeditationJSON.data/1)
    }
  end
end
