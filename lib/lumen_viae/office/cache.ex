defmodule LumenViae.Office.Cache do
  @moduledoc """
  Holds parsed offices so each one is fetched from the engine once.

  The office of a given date under given rubrics never changes, so this
  is nearly a forever-cache; the month-long TTL exists so upstream text
  corrections eventually arrive and so entries for one-off historical
  date lookups do not accumulate without bound. Same recipe as the
  geolocation cache: a supervised owner, a public named ETS table read
  directly by callers, and a periodic sweep. Per machine, like every ETS
  table here - two production machines each warm their own copy, which
  costs one extra upstream fetch per key and coordinates nothing.

  Only successful parses are stored. An upstream failure must stay a
  miss, or a five-minute outage would answer 503 for a month.
  """

  use GenServer

  @table :lumen_viae_office_cache
  @ttl_ms :timer.hours(24 * 30)
  @sweep_interval_ms :timer.hours(12)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def fetch(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at, do: {:ok, value}, else: :miss

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  def put(key, value) do
    expires_at = System.monotonic_time(:millisecond) + @ttl_ms
    :ets.insert(@table, {key, value, expires_at})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Empties the cache. For tests."
  def reset do
    :ets.delete_all_objects(@table)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)
end
