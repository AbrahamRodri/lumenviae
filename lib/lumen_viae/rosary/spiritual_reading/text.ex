defmodule LumenViae.Rosary.SpiritualReading.Text do
  @moduledoc """
  The Spiritual Reading shelf's books as the website reads them: each
  book's Project Gutenberg text, fetched by the server
  (`LumenViae.Rosary.SpiritualReading.Gutenberg`), cut into chapters by its
  edition's rules (`LumenViae.Rosary.SpiritualReading.Parser`) and held in
  this machine's memory, so each book is fetched once per machine per month
  and a visitor's browser never calls Gutenberg.

  Kept as the Divine Office's cache keeps its answers
  (`LumenViae.Office.Cache`): a supervised owner of a public named ETS
  table read directly by callers, a month-long time to live and a periodic
  sweep, per machine. A book is stored in pieces, its contents under one
  key and each chapter under its own, so a page copies out of the table
  only the chapter it shows, not the whole book.

  One download per cold book, owned by no visitor: a caller that misses
  asks this process for the book, which starts the download in a task of
  its own supervisor and answers every caller waiting on that book when it
  ends. A caller that goes away (a tab closed, a page that stops waiting)
  takes nothing with it: the download goes on and the book is stored for
  the next visitor. The whole download has a deadline (`@deadline_ms`),
  past which the task is stopped and the book counts as unreachable,
  unless it was stored a moment before, when the callers get it.

  A failure is remembered, so Gutenberg is not asked again by every
  visitor: unreachable for a minute (it may come back soon), unreadable
  (an edition that no longer cuts into chapters, or text the parser could
  not read) for an hour, since asking again only downloads the same book
  to fail the same way.

  In production (`config :lumen_viae, :spiritual_reading, warm: true`) the
  five books are fetched a while after boot, one at a time and spaced
  apart, through the same path, so the first visitor and crawlers after a
  deploy find them held.

  Keys carry the edition's fingerprint (`fingerprint/1`, the iOS app's
  `editionFingerprint`), so a change to a book's cutting rules in the
  catalogue retires its cached cut at the next deploy.
  """

  use GenServer

  require Logger

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.SpiritualReading.Gutenberg
  alias LumenViae.Rosary.SpiritualReading.Parser

  @table :lumen_viae_spiritual_reading_text
  @ttl_ms :timer.hours(24 * 30)
  @failure_ttl_ms :timer.minutes(1)
  @unreadable_ttl_ms :timer.hours(1)
  # The whole download and cut: Req's receive_timeout restarts with every
  # chunk, so a slow trickle is stopped here instead.
  @deadline_ms :timer.seconds(60)
  @warm_after_ms :timer.seconds(30)
  @warm_spacing_ms :timer.seconds(20)
  @fetches LumenViae.Rosary.SpiritualReading.Fetches
  @sweep_interval_ms :timer.hours(12)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  The book's contents, `{:ok, %{fingerprint:, chapters: [%{id:, part:, heading:, title:}]}}`,
  or `{:error, :unreachable | :unreadable}`. `info` is the book's
  catalogue entry. With `fetch: false` a book this machine does not hold
  yet answers `{:error, :cold}` rather than being fetched.
  """
  def contents(info, opts \\ []) do
    with :ok <- ensure_loaded(info, opts) do
      lookup({:contents, info.id, fingerprint(info)})
    end
  end

  @doc """
  One chapter, by its index from 0: `{:ok, %{id:, part:, heading:, title:, paragraphs:, notes:}}`,
  `{:error, :not_found}` for an index the book does not have, or
  `{:error, :unreachable | :unreadable | :cold}`, as `contents/2`.
  """
  def chapter(info, index, opts \\ []) when is_integer(index) do
    with :ok <- ensure_loaded(info, opts) do
      case lookup({:chapter, info.id, fingerprint(info), index}) do
        {:ok, chapter} -> {:ok, chapter}
        :miss -> {:error, :not_found}
      end
    end
  end

  defp ensure_loaded(info, opts) do
    key = {:contents, info.id, fingerprint(info)}

    case lookup(key) do
      {:ok, _contents} -> :ok
      {:error, reason} -> {:error, reason}
      :miss -> if Keyword.get(opts, :fetch, true), do: load_once(info, key), else: {:error, :cold}
    end
  end

  defp load_once(info, _key) do
    # The requester's callers ride along so a test's Req.Test stub (owned
    # by the test process) answers the download; nothing else reads them.
    callers = [self() | Process.get(:"$callers", [])]
    GenServer.call(__MODULE__, {:load, info, callers}, @deadline_ms + 5_000)
  catch
    # This process is restarting, or the download outran even the
    # deadline's grace: the reader is told to try again.
    :exit, _reason -> {:error, :unreachable}
  end

  # The download and the cut, in a task of this process's supervisor.
  defp load(info) do
    fingerprint = fingerprint(info)

    with {:ok, text} <- fetch(info),
         {:ok, book} <- cut(text, info) do
      store(info.id, fingerprint, book)
      :ok
    else
      {:error, reason} ->
        remember_failure(info.id, fingerprint, reason)
        {:error, reason}
    end
  end

  defp remember_failure(book_id, fingerprint, reason) do
    ttl = if reason == :unreadable, do: @unreadable_ttl_ms, else: @failure_ttl_ms
    put({:contents, book_id, fingerprint}, {:error, reason}, ttl)
  end

  defp fetch(info) do
    case Gutenberg.fetch_text(info.gutenberg_id) do
      {:ok, text} -> {:ok, text}
      {:error, _reason} -> {:error, :unreachable}
    end
  end

  # A text that cuts into no chapters is an edition that has changed shape,
  # and one the parser cannot read is no better: trying again would only
  # download it to fail the same way. Bytes that are not UTF-8 are read as
  # Latin-1, the one legacy shape worth catching (iOS LibraryService).
  defp cut(text, info) do
    text = if String.valid?(text), do: text, else: :unicode.characters_to_binary(text, :latin1)

    case Parser.parse(text, info) do
      %{chapters: []} ->
        Logger.error(
          "Spiritual Reading: #{info.id} (Gutenberg #{info.gutenberg_id}) cut into no chapters"
        )

        {:error, :unreadable}

      book ->
        {:ok, book}
    end
  rescue
    exception ->
      Logger.error(
        "Spiritual Reading: #{info.id} (Gutenberg #{info.gutenberg_id}) could not be cut: " <>
          Exception.message(exception)
      )

      {:error, :unreadable}
  end

  defp store(book_id, fingerprint, %{chapters: chapters}) do
    # The chapters outlive the contents by a minute, so the contents never
    # name a chapter the sweep has already taken.
    for chapter <- chapters,
        do: put({:chapter, book_id, fingerprint, chapter.id}, {:ok, chapter}, @ttl_ms + 60_000)

    contents = %{
      fingerprint: fingerprint,
      chapters: Enum.map(chapters, &Map.take(&1, [:id, :part, :heading, :title]))
    }

    # The contents last: until they are stored the book reads as missing,
    # so no caller finds contents whose chapters are not there yet.
    put({:contents, book_id, fingerprint}, {:ok, contents})
  end

  @doc """
  Everything that decides how a book is cut, in eight hex digits: the
  iOS app's `editionFingerprint` (FNV-1a over the edition's number, its
  rules, its curated titles and its heading corrections).
  """
  def fingerprint(info) do
    rules = info.parsing

    overrides =
      (info.heading_overrides || [])
      |> Enum.sort_by(& &1.chapter)
      |> Enum.map_join("\u0003", &"#{&1.chapter}=#{&1.heading}")

    parts = [
      Integer.to_string(info.gutenberg_id),
      rules.chapter_pattern,
      rules.part_pattern || "",
      rules.start_pattern || "",
      rules.stop_pattern || "",
      rules.note_pattern || "",
      rules.drop_pattern || "",
      to_string(rules.title_runs_to_blank_gap),
      Enum.join(info.chapter_titles || [], "\u0002"),
      overrides,
      Integer.to_string(rules.minimum_chapter_length)
    ]

    # Rules added after the first books were cached ride at the end, and
    # only when set, as on iOS.
    parts =
      if rules.maximum_title_length != 140,
        do: parts ++ [Integer.to_string(rules.maximum_title_length)],
        else: parts

    parts
    |> Enum.join("\u0001")
    |> fnv1a()
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(8, "0")
  end

  defp fnv1a(seed) do
    for <<byte <- seed>>, reduce: 2_166_136_261 do
      hash -> Bitwise.band(Bitwise.bxor(hash, byte) * 16_777_619, 0xFFFFFFFF)
    end
  end

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

  defp put(key, value, ttl_ms \\ @ttl_ms) do
    :ets.insert(@table, {key, value, System.monotonic_time(:millisecond) + ttl_ms})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Empties the table, so the next request fetches every book again. For the tests."
  def reset do
    :ets.delete_all_objects(@table)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, _supervisor} = Task.Supervisor.start_link(name: @fetches)
    schedule_sweep()

    if config(:warm, false), do: Process.send_after(self(), :warm, @warm_after_ms)

    # loading: key => %{task:, waiters:, timer:}; tasks: task ref => key
    {:ok, %{loading: %{}, tasks: %{}}}
  end

  @impl true
  def handle_call({:load, info, callers}, from, state) do
    key = {:contents, info.id, fingerprint(info)}

    case {lookup(key), state.loading} do
      {{:ok, _contents}, _loading} ->
        {:reply, :ok, state}

      {{:error, reason}, _loading} ->
        {:reply, {:error, reason}, state}

      {:miss, %{^key => entry}} ->
        {:noreply, put_in(state.loading[key], %{entry | waiters: [from | entry.waiters]})}

      {:miss, _loading} ->
        {:noreply, start_load(state, key, info, callers, [from])}
    end
  end

  @impl true
  def handle_info({ref, result}, state) when is_map_key(state.tasks, ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, finish(state, ref, result)}
  end

  # The task died without answering.
  def handle_info({:DOWN, ref, :process, _pid, reason}, state)
      when is_map_key(state.tasks, ref) do
    Logger.warning("Spiritual Reading: a download ended without an answer: #{inspect(reason)}")
    {:noreply, fail(state, ref)}
  end

  # The download ran past its deadline: stopped, and counted unreachable.
  def handle_info({:deadline, ref}, state) when is_map_key(state.tasks, ref) do
    %{task: task} = state.loading[state.tasks[ref]]
    Logger.warning("Spiritual Reading: a download passed #{@deadline_ms} ms; stopped")
    Process.demonitor(ref, [:flush])
    Task.Supervisor.terminate_child(@fetches, task.pid)
    {:noreply, fail(state, ref)}
  end

  def handle_info({:deadline, _ref}, state), do: {:noreply, state}

  def handle_info(:warm, state) do
    {:noreply, warm(state, Library.served(:spiritual_reading, "books"))}
  end

  def handle_info({:warm, books}, state), do: {:noreply, warm(state, books)}

  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  # One book now, the next after a pause: the shelf is warmed without ever
  # asking Gutenberg for two books at once.
  defp warm(state, []), do: state

  defp warm(state, [info | rest]) do
    key = {:contents, info.id, fingerprint(info)}

    state =
      if lookup(key) == :miss and not Map.has_key?(state.loading, key),
        do: start_load(state, key, info, [], []),
        else: state

    if rest != [], do: Process.send_after(self(), {:warm, rest}, @warm_spacing_ms)
    state
  end

  defp start_load(state, key, info, callers, waiters) do
    task =
      Task.Supervisor.async_nolink(@fetches, fn ->
        Process.put(:"$callers", callers)
        load(info)
      end)

    timer = Process.send_after(self(), {:deadline, task.ref}, @deadline_ms)
    entry = %{task: task, waiters: waiters, timer: timer, info: info}

    %{
      state
      | loading: Map.put(state.loading, key, entry),
        tasks: Map.put(state.tasks, task.ref, key)
    }
  end

  # The task may have stored the book a moment before its deadline (or
  # before it died): then the callers get it, and no failure is written
  # over it.
  defp fail(state, ref) do
    key = state.tasks[ref]

    case lookup(key) do
      {:ok, _contents} ->
        finish(state, ref, :ok)

      _missing ->
        %{info: info} = state.loading[key]
        remember_failure(info.id, fingerprint(info), :unreachable)
        finish(state, ref, {:error, :unreachable})
    end
  end

  defp finish(state, ref, result) do
    {key, tasks} = Map.pop(state.tasks, ref)
    {entry, loading} = Map.pop(state.loading, key)
    Process.cancel_timer(entry.timer)
    Enum.each(entry.waiters, &GenServer.reply(&1, result))
    %{state | loading: loading, tasks: tasks}
  end

  defp config(key, default) do
    :lumen_viae
    |> Application.get_env(:spiritual_reading, [])
    |> Keyword.get(key, default)
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)
end
