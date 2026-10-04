defmodule LumenViae.Ops.Maintenance.ClearOfficeCache do
  @moduledoc """
  Empties the Office cache on every machine in the cluster, itself
  included. The next request for each office fetches it from the engine
  again, so this is for after the engine's texts have been corrected, or to
  watch a warm happen from cold. Answers how many machines did it.
  """
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(_input, _opts, _context) do
    cleared =
      [node() | Node.list()]
      |> :erpc.multicall(LumenViae.Office, :clear_cache, [], :timer.seconds(5))
      |> Enum.count(&match?({:ok, :ok}, &1))

    {:ok, cleared}
  end
end
