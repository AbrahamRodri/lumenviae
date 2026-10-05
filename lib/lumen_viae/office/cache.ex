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

  ## One engine request per cold key

  `fetch_or_load/2` loads a missing key once however many callers ask for
  it at the same moment (at midnight, every app opening today's hours).
  The first caller to miss loads it, in its own process; the others wait
  for that load's answer, success or failure, instead of each asking the
  engine. This process only keeps the list of who is waiting for what. If
  the loader dies or its load raises, the first waiter becomes the loader.
  A waiter gives up after `@wait_ms`, longer than the engine client's own
  timeouts allow a request to take, leaves the list, and loads for itself,
  so a stuck load can delay a request but never hang it.

  ## Tests

  The table is shared by every test. A test that wants a cache of its own
  calls `isolate/0` in its setup: its keys, and those of the processes it
  starts, are then namespaced apart from every other test's. Only
  config/test.exs turns this on (`:isolate_office_cache`).
  """

  use GenServer

  @table :lumen_viae_office_cache
  @ttl_ms :timer.hours(24 * 30)
  @sweep_interval_ms :timer.hours(12)
  # The engine client allows 5s to connect and 15s to answer, and does not
  # retry, so a load finishes or fails well inside this.
  @wait_ms 25_000
  @namespace_key :lumen_viae_office_cache_namespace

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  The value under `key`, or what `load` returns, storing it on `{:ok, _}`.
  Concurrent callers for the same missing key share one `load`; see the
  module. `wait_ms`, how long to wait on another caller's load, is
  `@wait_ms` except in the tests.
  """
  def fetch_or_load(key, load, wait_ms \\ @wait_ms) when is_function(load, 0) do
    case fetch(key) do
      {:ok, value} -> {:ok, value}
      :miss -> claim(key, load, wait_ms)
    end
  end

  defp claim(key, load, wait_ms) do
    case wait_for_claim(key, wait_ms) do
      :load ->
        load_and_release(key, load)

      {:loaded, result} ->
        result

      :gave_up ->
        # Off the waiting list, so this caller is neither answered nor
        # promoted later; and if it was promoted in the moment it gave up,
        # the key passes to the next waiter.
        GenServer.cast(__MODULE__, {:withdraw, namespaced(key), self()})
        load_and_store(key, load)
    end
  end

  defp wait_for_claim(key, wait_ms) do
    GenServer.call(__MODULE__, {:claim, namespaced(key)}, wait_ms)
  catch
    # No coordinator (it is restarting), or the load waited on has run
    # past every timeout: load for ourselves rather than fail the request.
    :exit, _reason -> :gave_up
  end

  # The key is released on every path. A load that raises may leave its
  # process alive (a GraphQL resolver catches the error and the connection
  # serves its next request), so without the `catch` the key would stay
  # claimed until that process ended, and every caller would wait out
  # `@wait_ms` for it. On a raise the waiters are not given the exception:
  # the first of them loads instead.
  defp load_and_release(key, load) do
    result = load_and_store(key, load)
    GenServer.cast(__MODULE__, {:release, namespaced(key), self(), {:loaded, result}})
    result
  catch
    kind, reason ->
      GenServer.cast(__MODULE__, {:release, namespaced(key), self(), :retry})
      :erlang.raise(kind, reason, __STACKTRACE__)
  end

  defp load_and_store(key, load) do
    with {:ok, value} <- load.() do
      put(key, value)
      {:ok, value}
    end
  end

  @doc """
  Gives the calling test, and the processes it starts, cache keys of its
  own, so it neither sees nor leaves entries other tests share.
  """
  def isolate, do: Process.put(@namespace_key, make_ref())

  # Only the test configuration turns the namespaces on, so production
  # never looks anything up for them.
  if Application.compile_env(:lumen_viae, :isolate_office_cache, false) do
    # The namespace of the calling process, or of the test that started it.
    defp namespaced(key) do
      namespace =
        Enum.find_value([self() | Process.get(:"$callers", [])], fn
          pid when pid == self() -> Process.get(@namespace_key)
          pid -> namespace_of(pid)
        end)

      {namespace, key}
    end

    defp namespace_of(pid) do
      case Process.info(pid, :dictionary) do
        {:dictionary, dictionary} -> Keyword.get(dictionary, @namespace_key)
        nil -> nil
      end
    end
  else
    defp namespaced(key), do: {nil, key}
  end

  def fetch(key) do
    key = namespaced(key)

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
    :ets.insert(@table, {namespaced(key), value, expires_at})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "How many entries the table holds and their size in bytes."
  def stats do
    case {:ets.info(@table, :size), :ets.info(@table, :memory)} do
      {size, words} when is_integer(size) and is_integer(words) ->
        %{entries: size, bytes: words * :erlang.system_info(:wordsize)}

      _no_table ->
        %{entries: 0, bytes: 0}
    end
  end

  @doc "Empties the cache: for tests, and the console's System screen."
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
    # key => %{loader: pid, monitor: ref, waiters: [from]}
    {:ok, %{loading: %{}}}
  end

  @impl true
  def handle_call({:claim, key}, {pid, _tag} = from, state) do
    case state.loading do
      %{^key => entry} ->
        entry = %{entry | waiters: entry.waiters ++ [from]}
        {:noreply, put_in(state.loading[key], entry)}

      %{} ->
        entry = %{loader: pid, monitor: Process.monitor(pid), waiters: []}
        {:reply, :load, put_in(state.loading[key], entry)}
    end
  end

  @impl true
  def handle_cast({:release, key, pid, outcome}, state) do
    case state.loading do
      %{^key => %{loader: ^pid} = entry} ->
        Process.demonitor(entry.monitor, [:flush])

        case outcome do
          {:loaded, result} ->
            Enum.each(entry.waiters, &GenServer.reply(&1, {:loaded, result}))
            {:noreply, %{state | loading: Map.delete(state.loading, key)}}

          :retry ->
            {:noreply, hand_on(state, key, entry.waiters)}
        end

      %{} ->
        {:noreply, state}
    end
  end

  # A waiter that gave up. If it had been promoted to loader in the
  # meantime, it will not load under this claim, so the key passes on.
  def handle_cast({:withdraw, key, pid}, state) do
    case state.loading do
      %{^key => %{loader: ^pid} = entry} ->
        Process.demonitor(entry.monitor, [:flush])
        {:noreply, hand_on(state, key, entry.waiters)}

      %{^key => entry} ->
        waiters = Enum.reject(entry.waiters, fn {waiter, _tag} -> waiter == pid end)
        {:noreply, put_in(state.loading[key], %{entry | waiters: waiters})}

      %{} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    # The loader died: the first waiter loads instead.
    case Enum.find(state.loading, fn {_key, entry} -> entry.monitor == ref end) do
      {key, entry} -> {:noreply, hand_on(state, key, entry.waiters)}
      nil -> {:noreply, state}
    end
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  # The claim passes to the first waiter, or ends if nobody is waiting.
  defp hand_on(state, key, [{next, _tag} = from | rest]) do
    GenServer.reply(from, :load)
    entry = %{loader: next, monitor: Process.monitor(next), waiters: rest}
    put_in(state.loading[key], entry)
  end

  defp hand_on(state, key, []), do: %{state | loading: Map.delete(state.loading, key)}

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)
end
