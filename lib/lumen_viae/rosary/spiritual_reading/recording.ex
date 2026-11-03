defmodule LumenViae.Rosary.SpiritualReading.Recording do
  @moduledoc """
  The track lists of the Spiritual Reading shelf's LibriVox recordings, as
  the website reads them: fetched from LibriVox by the server
  (`LumenViae.Rosary.SpiritualReading.LibriVox`), read into plain maps and
  held in this machine's memory for a month, so a visitor's browser never
  asks LibriVox for them. The recordings themselves stream in the browser
  from the Internet Archive, as in the apps.

  ## Who fetches

  A caller reads the table itself. On a miss it asks this process, which
  runs the fetch in a task of its own supervisor, owned by no page: a
  visitor who closes the tab, or a LiveView that stops waiting, never
  aborts a fetch others share. Callers asking for the same book while it
  is on its way wait for that one fetch. The task reads what came back and
  stores it, or holds the failure, before it answers, so the answer lands
  even when nobody waits for it any more. A fetch has 15 seconds in all;
  past that it is stopped and counted a failure, unless it stored the
  tracks a moment before, which then stand.

  ## Bounds

  The keys are the catalogue's LibriVox numbers (four books), so the
  table holds at most four track lists and their holds. Besides: at most
  2 fetches run at once and at most 12 start a minute on a machine
  (`LumenViae.Hammer`); past either the answer is `{:error, :unavailable}`
  and nothing is held, so the next visitor may ask again.

  ## Failures are held

  Anything but a track list (LibriVox down or slow, a non-200, a
  redirect, a body that is not JSON or past the cap, JSON of another
  shape, a book with no playable tracks) is `{:error, :unavailable}`, the
  cause in the log, and is held: that book is not asked for again for
  five minutes. When LibriVox itself is failing (it cannot be reached, it
  times out, it answers 5xx) no book at all is asked for a minute. A
  failure never overwrites a stored track list.

  ## A track

  `%{id:, title:, url:, seconds:}`: the feed's section id and title, the
  recording's address over https (LibriVox still lists some as http), and
  its length in seconds when the feed gives one. Only tracks on the
  Internet Archive (`archive.org` or a host beneath it) are kept, the host
  the privacy policy names.

  ## Tests

  The table is shared by every test. A test that wants its own calls
  `isolate/0` (ConnCase does); its keys, and those of the processes it
  starts, are then namespaced apart. Only config/test.exs turns this on
  (`:isolate_spiritual_reading_cache`).
  """

  use GenServer

  require Logger

  alias LumenViae.Rosary.SpiritualReading.LibriVox

  @table :lumen_viae_spiritual_reading_recordings
  @ttl_ms :timer.hours(24 * 30)
  @key_hold_ms :timer.minutes(5)
  @outage_hold_ms :timer.minutes(1)
  @deadline_ms 15_000
  @max_running 2
  @per_minute 12
  @sweep_interval_ms :timer.hours(12)
  @tasks LumenViae.Rosary.SpiritualReading.RecordingFetches
  @namespace_key :lumen_viae_spiritual_reading_recordings_namespace

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  The tracks of the book's recording, `{:ok, [track]}`, or
  `{:error, :unavailable}`. `info` is the book's catalogue entry, which
  must name a `librivox_id`. With `fetch: false` a list this machine does
  not hold yet answers `{:error, :cold}` rather than being fetched.
  """
  def tracks(%{librivox_id: id}, opts \\ []) when is_integer(id) do
    key = {:tracks, id}
    namespace = namespace()

    cond do
      match?({:ok, _tracks}, cached = lookup({namespace, key})) -> cached
      held?(namespace, key) -> {:error, :unavailable}
      not Keyword.get(opts, :fetch, true) -> {:error, :cold}
      true -> ask(namespace, id)
    end
  end

  defp held?(namespace, key) do
    match?({:ok, _held}, lookup({namespace, {:failed, :any}})) or
      match?({:ok, _held}, lookup({namespace, {:failed, key}}))
  end

  defp ask(namespace, id) do
    callers = [self() | Process.get(:"$callers", [])]
    limits = limits()

    GenServer.call(
      __MODULE__,
      {:load, {namespace, id}, callers, limits},
      limits.deadline_ms + 5_000
    )
  catch
    :exit, _reason -> {:error, :unavailable}
  end

  # The bounds, from `config :lumen_viae, :librivox` where set, and a
  # test's own deadline (`Process.put(:librivox_deadline_ms, ms)`).
  defp limits do
    config = Application.get_env(:lumen_viae, :librivox, [])

    %{
      max_running: Keyword.get(config, :max_running, @max_running),
      per_minute: Keyword.get(config, :per_minute, @per_minute),
      deadline_ms:
        Process.get(:librivox_deadline_ms) || Keyword.get(config, :deadline_ms, @deadline_ms)
    }
  end

  @doc false
  # Stores a track list as the fetch's task would, in the caller's
  # namespace: for the test of a store landing just before the deadline.
  def put_tracks(librivox_id, tracks),
    do: put({namespace(), {:tracks, librivox_id}}, {:ok, tracks}, @ttl_ms)

  # In the task: fetch, read, and store the tracks or hold the failure.
  defp load(namespace, id) do
    key = {:tracks, id}

    with {:ok, json} <- LibriVox.fetch_audiobook(id),
         {:ok, tracks} <- read(json, id) do
      put({namespace, key}, {:ok, tracks}, @ttl_ms)
      {:ok, tracks}
    else
      {:error, reason} -> fail(namespace, key, outage?(reason))
    end
  rescue
    exception ->
      Logger.error("LibriVox's #{id} raised: #{Exception.message(exception)}")
      fail(namespace, {:tracks, id}, false)
  end

  # LibriVox itself failing, rather than this one book.
  defp outage?(:upstream_unreachable), do: true
  defp outage?({:upstream_status, status}) when status >= 500, do: true
  defp outage?(_reason), do: false

  defp fail(namespace, key, outage?) do
    put({namespace, {:failed, key}}, {:ok, true}, @key_hold_ms)
    if outage?, do: put({namespace, {:failed, :any}}, {:ok, true}, @outage_hold_ms)
    {:error, :unavailable}
  end

  @doc false
  # The feed's first book's sections with a recording on the Internet
  # Archive, as tracks; none is no recording (LibriVox answers 200 with no
  # sections often enough, and holding [] would retire the recording).
  def read(%{"books" => [%{"sections" => sections} | _rest]}, _id) when is_list(sections) do
    case for(section <- sections, track = track(section), track != nil, do: track) do
      [] -> unreadable("has no playable tracks")
      tracks -> {:ok, tracks}
    end
  end

  def read(_json, id), do: unreadable("#{id} was not in the shape the shelf reads")

  defp unreadable(why) do
    Logger.warning("LibriVox's feed #{why}")
    {:error, :unreadable}
  end

  defp track(%{"id" => id, "listen_url" => url} = section)
       when (is_binary(id) or is_integer(id)) and is_binary(url) do
    with url when url != nil <- archive_url(url) do
      %{
        id: to_string(id),
        title: string(section["title"]),
        url: url,
        seconds: seconds(section["playtime"])
      }
    end
  end

  defp track(_section), do: nil

  # Over https, and only on the Internet Archive.
  defp archive_url(url) do
    url =
      if String.starts_with?(url, "http://"),
        do: "https://" <> binary_part(url, 7, byte_size(url) - 7),
        else: url

    case URI.parse(url) do
      %URI{scheme: "https", host: host, userinfo: nil} when is_binary(host) ->
        if host == "archive.org" or String.ends_with?(host, ".archive.org"), do: url

      _other ->
        nil
    end
  end

  # The feed's playtime is seconds as a string; "h:mm:ss" is read too.
  defp seconds(playtime) when is_binary(playtime) do
    playtime = String.trim(playtime)

    value =
      case Integer.parse(playtime) do
        {n, ""} ->
          n

        _other ->
          parts = String.split(playtime, ":")
          numbers = for part <- parts, {n, ""} <- [Integer.parse(part)], do: n

          if length(parts) in 2..3 and length(numbers) == length(parts),
            do: Enum.reduce(numbers, 0, &(&2 * 60 + &1))
      end

    if is_integer(value) and value > 0, do: value
  end

  defp seconds(playtime) when is_integer(playtime) and playtime > 0, do: playtime
  defp seconds(_playtime), do: nil

  defp string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp string(_value), do: nil

  # -- The table ------------------------------------------------------------

  defp lookup(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at, do: value, else: :miss

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp put(key, value, ttl_ms) do
    :ets.insert(@table, {key, value, System.monotonic_time(:millisecond) + ttl_ms})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Gives the calling test, and the processes it starts, keys of its own,
  so it neither sees nor leaves entries other tests share.
  """
  def isolate, do: Process.put(@namespace_key, make_ref())

  # Only the test configuration turns the namespaces on, so production
  # never looks anything up for them.
  if Application.compile_env(:lumen_viae, :isolate_spiritual_reading_cache, false) do
    defp namespace do
      Enum.find_value([self() | Process.get(:"$callers", [])], fn
        pid when pid == self() -> Process.get(@namespace_key)
        pid -> namespace_of(pid)
      end)
    end

    defp namespace_of(pid) do
      case Process.info(pid, :dictionary) do
        {:dictionary, dictionary} -> Keyword.get(dictionary, @namespace_key)
        nil -> nil
      end
    end
  else
    defp namespace, do: nil
  end

  # -- The process that owns the fetches ------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, _supervisor} = Task.Supervisor.start_link(name: @tasks)
    schedule_sweep()
    # loading: {namespace, id} => %{task:, timer:, waiters:}
    {:ok, %{loading: %{}}}
  end

  @impl true
  def handle_call({:load, {namespace, id} = key, callers, limits}, from, state) do
    cond do
      Map.has_key?(state.loading, key) ->
        {:noreply, update_in(state.loading[key].waiters, &[from | &1])}

      # Stored or held since the caller looked: answer from the table.
      match?({:ok, _tracks}, cached = lookup({namespace, {:tracks, id}})) ->
        {:reply, cached, state}

      held?(namespace, {:tracks, id}) ->
        {:reply, {:error, :unavailable}, state}

      room?(state, namespace, limits) ->
        {:noreply, start(state, key, callers, limits, from)}

      true ->
        {:reply, {:error, :unavailable}, state}
    end
  end

  # Under the cap of fetches at once and of fetches a minute (counted per
  # test namespace in the suite, one count in production).
  defp room?(state, namespace, limits) do
    running = Enum.count(state.loading, fn {{ns, _id}, _entry} -> ns == namespace end)

    running < limits.max_running and
      match?(
        {:allow, _count},
        LumenViae.Hammer.hit("librivox_fetch:#{inspect(namespace)}", 60_000, limits.per_minute)
      )
  end

  defp start(state, {namespace, id} = key, callers, limits, from) do
    task =
      Task.Supervisor.async_nolink(@tasks, fn ->
        # Whose request this is, for the tests' stubs; nothing in
        # production reads it.
        Process.put(:"$callers", callers)
        load(namespace, id)
      end)

    timer = Process.send_after(self(), {:deadline, key, task.ref}, limits.deadline_ms)
    put_in(state.loading[key], %{task: task, timer: timer, waiters: [from]})
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, finish(state, ref, result)}
  end

  # The task died without answering (it never should: `load/2` rescues).
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state),
    do: {:noreply, finish(state, ref, {:error, :unavailable})}

  def handle_info({:deadline, {namespace, id} = key, ref}, state) do
    case state.loading do
      %{^key => %{task: %{ref: ^ref} = task}} ->
        Task.Supervisor.terminate_child(@tasks, task.pid)
        Process.demonitor(ref, [:flush])

        # The task may have stored the tracks a moment before the
        # deadline: then the callers get them, and no failure is held
        # over them.
        result =
          case lookup({namespace, {:tracks, id}}) do
            {:ok, tracks} ->
              {:ok, tracks}

            _missing ->
              Logger.warning("LibriVox's #{id} passed its deadline")
              fail(namespace, {:tracks, id}, true)
          end

        {:noreply, finish(state, ref, result)}

      _gone ->
        {:noreply, state}
    end
  end

  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp finish(state, ref, result) do
    case Enum.find(state.loading, fn {_key, entry} -> entry.task.ref == ref end) do
      nil ->
        state

      {key, entry} ->
        Process.cancel_timer(entry.timer)
        Enum.each(entry.waiters, &GenServer.reply(&1, result))
        %{state | loading: Map.delete(state.loading, key)}
    end
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)
end
