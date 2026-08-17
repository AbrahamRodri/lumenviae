defmodule LumenViaeWeb.API.CompletionJSON do
  @doc """
  Renders a rosary completion.
  """
  def show(%{completion: completion}) do
    %{data: data(completion)}
  end

  defp data(completion) do
    %{
      id: completion.id,
      meditation_set_id: completion.meditation_set_id,
      completed_at: completion.completed_at
    }
  end
end
