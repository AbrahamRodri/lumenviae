defmodule LumenViae.Office.Missal do
  @moduledoc """
  The Daily Missal's texts as the website reads them: a day's propers, a
  year's calendar and the Order of Mass, fetched from Missale Meum by the
  server (`LumenViae.Office.MissaleMeum`), read into plain maps and held
  in the Office's cache (`LumenViae.Office.Cache`), so each is fetched
  once per machine per month and a visitor's browser never calls
  Missale Meum. The propers of a date never change once published.

  ## Who fetches

  A caller reads the cache itself. On a miss it asks this process, which
  runs the fetch in a task of its own supervisor (`LumenViae.Office.MissalTasks`),
  owned by no page: a visitor who closes the tab, or a LiveView that
  cancels its own wait, never aborts a fetch others share. Callers asking
  for the same key while it is on its way wait for that one fetch. The
  task reads what came back and stores it, or holds the failure, before
  it answers; so the answer lands in the cache even when nobody waits for
  it any more. A fetch has 20 seconds in all; past that it is
  stopped and counted as a failure.

  ## Failures are held

  Anything but the JSON the Missal reads (Missale Meum down or slow, a
  non-200, a redirect, an HTML block page with a 200, a body past the
  client's cap, JSON of another shape) is `{:error, :missal_unavailable}`,
  the cause kept in the log, and is held: that key is not asked for again
  for five minutes, and no key at all for one, since a Missale Meum that
  fails one request is likely failing all of them. So no number of
  visitors, retries or dates can make the server hammer it while it is
  down.

  Every passage of the Missal is an `[english, latin]` pair; a rubric of
  the Order of Mass is a single text. Both are kept as they come, the
  strings only.
  """

  use GenServer

  require Logger

  alias LumenViae.Office.Cache
  alias LumenViae.Office.MissaleMeum

  @key_hold_ms :timer.minutes(5)
  @outage_hold_ms :timer.minutes(1)
  @deadline_ms 20_000
  # Longer than the deadline, so a caller always hears the fetch's answer.
  @call_timeout_ms 25_000
  @tasks LumenViae.Office.MissalTasks

  @doc "The task supervisor the fetches run under, for the application to start."
  def task_supervisor, do: @tasks

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Every Mass said on `date`, `{:ok, [mass]}`: usually one, three on
  Christmas and All Souls, none for a day Missale Meum has no texts for.
  Each mass is `%{id:, title:, description:, rank:, colors:, tempora:,
  commemorations:, sections:}`, a section `%{id:, label:, body:}`.
  """
  def propers(%Date{} = date) do
    get({:missal, :proper, date}, fn -> MissaleMeum.fetch_proper(date) end, &masses/1)
  end

  @doc """
  The year's calendar, `{:ok, %{date => day}}`, each day `%{title:, rank:,
  colors:, commemorations:}`.
  """
  def calendar(year) when is_integer(year) do
    get({:missal, :calendar, year}, fn -> MissaleMeum.fetch_calendar(year) end, &calendar_days/1)
  end

  @doc "The Order of Mass, `{:ok, [section]}`, Asperges to the Last Gospel."
  def ordo, do: get({:missal, :ordo}, &MissaleMeum.fetch_ordo/0, &ordo_sections/1)

  # -- Asking -------------------------------------------------------------------

  defp get(key, fetch, reader) do
    cond do
      match?({:ok, _value}, cached = Cache.fetch(key)) -> cached
      held?(key) -> {:error, :missal_unavailable}
      true -> ask(key, fetch, reader)
    end
  end

  defp held?(key) do
    match?({:ok, _held}, Cache.fetch({:missal_failed, :any})) or
      match?({:ok, _held}, Cache.fetch({:missal_failed, key}))
  end

  defp ask(key, fetch, reader) do
    namespace = Cache.namespace()
    callers = [self() | Process.get(:"$callers", [])]
    job = fn -> load(namespace, key, fetch, reader) end
    GenServer.call(__MODULE__, {:load, {namespace, key}, job, callers}, @call_timeout_ms)
  catch
    :exit, _reason -> {:error, :missal_unavailable}
  end

  # In the task: fetch, read, and store the value or hold the failure.
  defp load(namespace, key, fetch, reader) do
    with {:ok, json} <- fetch.(),
         {:ok, value} <- read(json, reader, key) do
      Cache.put_in_namespace(namespace, key, value)
      {:ok, value}
    else
      {:error, _reason} -> fail(namespace, key)
    end
  rescue
    exception ->
      Logger.error("The Missal's #{inspect(key)} raised: #{Exception.message(exception)}")
      fail(namespace, key)
  end

  defp fail(namespace, key) do
    Cache.put_in_namespace(namespace, {:missal_failed, key}, true, @key_hold_ms)
    Cache.put_in_namespace(namespace, {:missal_failed, :any}, true, @outage_hold_ms)
    {:error, :missal_unavailable}
  end

  defp read(json, reader, key) do
    case reader.(json) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        Logger.error("Missale Meum's #{inspect(key)} was not in the shape the Missal reads")
        {:error, :unreadable}
    end
  end

  # -- The process that owns the fetches ----------------------------------------

  @impl true
  def init(_opts), do: {:ok, %{loading: %{}}}

  @impl true
  def handle_call({:load, key, job, callers}, from, state) do
    case state.loading do
      %{^key => entry} ->
        {:noreply, put_in(state.loading[key], %{entry | waiters: [from | entry.waiters]})}

      %{} ->
        task =
          Task.Supervisor.async_nolink(@tasks, fn ->
            # Whose request this is, for the tests' stubs and cache
            # namespaces; nothing in production reads it.
            Process.put(:"$callers", callers)
            job.()
          end)

        timer = Process.send_after(self(), {:deadline, key, task.ref}, @deadline_ms)
        entry = %{task: task, timer: timer, waiters: [from]}
        {:noreply, put_in(state.loading[key], entry)}
    end
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, finish(state, ref, result)}
  end

  # The task died without answering (it never should: `load/4` rescues).
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state),
    do: {:noreply, finish(state, ref, {:error, :missal_unavailable})}

  def handle_info({:deadline, {namespace, key}, ref}, state) do
    case Enum.find(state.loading, fn {_key, entry} -> entry.task.ref == ref end) do
      nil ->
        {:noreply, state}

      {_key, entry} ->
        Task.Supervisor.terminate_child(@tasks, entry.task.pid)
        Process.demonitor(ref, [:flush])

        # The task may have stored the value a moment before the deadline:
        # then the callers get it, and no failure is held over it.
        result =
          case Cache.fetch_in_namespace(namespace, key) do
            {:ok, value} ->
              {:ok, value}

            :miss ->
              Logger.warning("Missale Meum's #{inspect(key)} passed its deadline")
              fail(namespace, key)
          end

        {:noreply, finish(state, ref, result)}
    end
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

  # -- Reading ------------------------------------------------------------------

  defp masses(list) when is_list(list) do
    if Enum.all?(list, &mass?/1), do: {:ok, Enum.map(list, &mass/1)}, else: :error
  end

  defp masses(_json), do: :error

  defp mass?(%{"info" => %{"title" => title}, "sections" => sections})
       when is_binary(title) and is_list(sections),
       do: true

  defp mass?(_entry), do: false

  defp mass(%{"info" => info, "sections" => sections}) do
    %{
      id: string(info["id"]),
      title: String.trim(info["title"]),
      description: string(info["description"]),
      rank: rank(info["rank"]),
      colors: colors(info["colors"]),
      tempora: string(info["tempora"]),
      commemorations: commemorations(info["commemorations"]),
      sections: sections(sections)
    }
  end

  defp calendar_days(list) when is_list(list) do
    days =
      for %{"id" => id, "title" => title} = day <- list,
          is_binary(title),
          {:ok, date} <- [Date.from_iso8601(to_string(id))],
          into: %{} do
        {date,
         %{
           title: String.trim(title),
           rank: rank(day["rank"]),
           colors: colors(day["colors"]),
           commemorations: commemorations(day["commemorations"])
         }}
      end

    if days == %{} and list != [], do: :error, else: {:ok, days}
  end

  defp calendar_days(_json), do: :error

  defp ordo_sections([%{"sections" => sections} | _rest]) when is_list(sections),
    do: {:ok, sections(sections)}

  defp ordo_sections(_json), do: :error

  # The sections with something to read, each passage its strings alone.
  defp sections(sections) do
    for %{"body" => body} = section <- sections,
        is_list(body),
        passages = passages(body),
        passages != [] do
      %{id: string(section["id"]), label: string(section["label"]), body: passages}
    end
  end

  defp passages(body) do
    for passage <- body,
        is_list(passage),
        texts = Enum.filter(passage, &is_binary/1),
        Enum.any?(texts, &(String.trim(&1) != "")),
        do: Enum.take(texts, 2)
  end

  defp commemorations(list) when is_list(list) do
    for %{"title" => title} <- list, is_binary(title), String.trim(title) != "", do: title
  end

  defp commemorations(_other), do: []

  defp colors(list) when is_list(list), do: Enum.filter(list, &is_binary/1)
  defp colors(_other), do: []

  defp rank(rank) when is_integer(rank) and rank in 1..4, do: rank
  defp rank(_rank), do: nil

  defp string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp string(_value), do: nil
end
