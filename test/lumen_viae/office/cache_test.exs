defmodule LumenViae.Office.CacheTest do
  @moduledoc """
  One engine request per cold key: concurrent callers for the same missing
  key share one load, success or failure, and a load that dies hands the
  key to the next caller.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Office.Cache

  setup do
    Cache.isolate()
    :ok
  end

  # Starts `n` callers of `fetch_or_load(key, load)` as tasks of this test
  # (so they share its namespace), and waits until all of them have asked.
  defp concurrent(n, key, load) do
    tasks = for _ <- 1..n, do: Task.async(fn -> Cache.fetch_or_load(key, load) end)
    Task.await_many(tasks, 5_000)
  end

  # A load that tells the test it ran, then waits to be let go, so the
  # other callers arrive while it is in flight.
  defp gated_load(test_pid, result) do
    fn ->
      send(test_pid, {:loading, self()})

      receive do
        :go -> result
      after
        2_000 -> result
      end
    end
  end

  defp release_after_others_wait(n) do
    assert_receive {:loading, loader}, 1_000
    wait_until(fn -> waiting() == n - 1 end)
    send(loader, :go)
  end

  defp waiting do
    %{loading: loading} = :sys.get_state(Cache)
    loading |> Map.values() |> Enum.map(&length(&1.waiters)) |> Enum.sum()
  end

  defp wait_until(fun, tries \\ 100) do
    cond do
      fun.() -> :ok
      tries == 0 -> flunk("condition never held")
      true -> Process.sleep(10) && wait_until(fun, tries - 1)
    end
  end

  test "concurrent misses for one key run one load and all get its value" do
    test_pid = self()
    key = {:test, make_ref()}

    task = Task.async(fn -> concurrent(5, key, gated_load(test_pid, {:ok, :office})) end)
    release_after_others_wait(5)

    assert Task.await(task) == List.duplicate({:ok, :office}, 5)
    refute_received {:loading, _another}
    assert Cache.fetch(key) == {:ok, :office}
  end

  test "a failed load is shared with its waiters and is not stored" do
    test_pid = self()
    key = {:test, make_ref()}

    task = Task.async(fn -> concurrent(3, key, gated_load(test_pid, {:error, :down})) end)
    release_after_others_wait(3)

    assert Task.await(task) == List.duplicate({:error, :down}, 3)
    assert Cache.fetch(key) == :miss
    assert Cache.fetch_or_load(key, fn -> {:ok, :back} end) == {:ok, :back}
  end

  test "a load that crashes frees its key for the next caller" do
    test_pid = self()
    key = {:test, make_ref()}

    {loader, monitor} =
      spawn_monitor(fn ->
        Process.put(:"$callers", [test_pid])
        Cache.fetch_or_load(key, fn -> send(test_pid, {:loading, self()}) && exit(:crashed) end)
      end)

    assert_receive {:loading, _first}
    assert_receive {:DOWN, ^monitor, :process, _, :crashed}

    assert Cache.fetch_or_load(key, fn -> {:ok, :second} end) == {:ok, :second}
    assert %{loading: loading} = :sys.get_state(Cache)
    refute Enum.any?(Map.values(loading), &(&1.loader == loader))
  end

  test "a waiter whose loader dies mid-load is promoted to load" do
    test_pid = self()
    key = {:test, make_ref()}

    loader =
      spawn(fn ->
        Process.put(:"$callers", [test_pid])

        Cache.fetch_or_load(key, fn ->
          send(test_pid, {:loading, self()})
          Process.sleep(:infinity)
        end)
      end)

    assert_receive {:loading, ^loader}
    waiter = Task.async(fn -> Cache.fetch_or_load(key, fn -> {:ok, :promoted} end) end)
    wait_until(fn -> waiting() == 1 end)

    Process.exit(loader, :kill)

    assert Task.await(waiter) == {:ok, :promoted}
    assert Cache.fetch(key) == {:ok, :promoted}
  end

  test "isolated tests do not see each other's entries" do
    key = {:test, :shared_name}
    :ok = Cache.put(key, :mine)

    other =
      Task.async(fn ->
        # A process outside this test (no $callers), in a namespace of its own.
        Process.delete(:"$callers")
        Cache.isolate()
        Cache.fetch(key)
      end)

    assert Task.await(other) == :miss
    assert Cache.fetch(key) == {:ok, :mine}
  end
end
