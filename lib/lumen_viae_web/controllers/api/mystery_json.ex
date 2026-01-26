defmodule LumenViaeWeb.API.MysteryJSON do
  alias LumenViae.Rosary.Mystery

  @doc """
  Renders a list of mysteries.
  """
  def index(%{mysteries: mysteries}) do
    %{data: Enum.map(mysteries, &data/1)}
  end

  @doc """
  Renders a single mystery.
  """
  def data(%Mystery{} = mystery) do
    %{
      id: mystery.id,
      name: mystery.name,
      category: mystery.category,
      order: mystery.order,
      days_prayed: mystery.days_prayed,
      description: mystery.description,
      scripture_reference: mystery.scripture_reference
    }
  end
end
