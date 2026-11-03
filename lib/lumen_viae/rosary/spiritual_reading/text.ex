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

  One fetch per cold book: the first caller to miss loads it inside a
  `:global` lock on this node, and the callers that arrive meanwhile wait
  for the lock, then find the book stored. A failure is remembered for a
  minute, so a Gutenberg that is down is not asked again by every visitor
  while it stays down, and is asked again soon after.

  Keys carry the edition's fingerprint (`fingerprint/1`, the iOS app's
  `editionFingerprint`), so a change to a book's cutting rules in the
  catalogue retires its cached cut at the next deploy.
  """

  use GenServer

  require Logger

  alias LumenViae.Rosary.SpiritualReading.Gutenberg
  alias LumenViae.Rosary.SpiritualReading.Parser

  @table :lumen_viae_spiritual_reading_text
  @ttl_ms :timer.hours(24 * 30)
  @failure_ttl_ms :timer.minutes(1)
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

  defp load_once(info, key) do
    :global.trans(
      {{__MODULE__, key}, self()},
      fn ->
        case lookup(key) do
          {:ok, _contents} -> :ok
          {:error, reason} -> {:error, reason}
          :miss -> load(info)
        end
      end,
      [node()]
    )
  end

  defp load(info) do
    fingerprint = fingerprint(info)

    with {:ok, text} <- fetch(info),
         {:ok, book} <- cut(text, info) do
      store(info.id, fingerprint, book)
      :ok
    else
      {:error, reason} ->
        put({:contents, info.id, fingerprint}, {:error, reason}, @failure_ttl_ms)
        {:error, reason}
    end
  end

  defp fetch(info) do
    case Gutenberg.fetch_text(info.gutenberg_id) do
      {:ok, text} -> {:ok, text}
      {:error, _reason} -> {:error, :unreachable}
    end
  end

  # A text that cuts into no chapters is an edition that has changed shape:
  # trying again would only download it to fail the same way.
  defp cut(text, info) do
    case Parser.parse(text, info) do
      %{chapters: []} ->
        Logger.error(
          "Spiritual Reading: #{info.id} (Gutenberg #{info.gutenberg_id}) cut into no chapters"
        )

        {:error, :unreadable}

      book ->
        {:ok, book}
    end
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
