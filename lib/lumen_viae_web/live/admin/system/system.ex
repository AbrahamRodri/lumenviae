defmodule LumenViaeWeb.Live.Admin.System do
  @moduledoc """
  The running app, for whoever is looking after it: the release and the VM,
  the database, the job queues and what failed in them, the crontab, the
  Office cache and the third parties the app depends on.

  The dashboard answers "is the library in order and is anyone praying";
  this answers "is the machinery in order". Everything is read through
  `LumenViae.Ops`. The two things it can do - run a scheduled job now,
  empty the Office cache - are actions on `LumenViae.Ops.Maintenance`,
  called with the signed-in admin as actor, so the policies decide.

  **Every number is a link**, as on the dashboard: a queue's counts land on
  Oban Web filtered to that queue and state, and a failure on the job.

  The third-party probes are network calls, each with its own timeout, so
  they run after the page is up and fill in as they answer; the page never
  waits on them. Probing the Office engine wakes it if it is suspended.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.CentralTime
  alias LumenViae.Ops

  @failures 10

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "System")
     |> assign(:probes, Map.new(Ops.probe_names(), &{&1, :checking}))
     |> load()
     |> start_probes()}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply,
     socket
     |> assign(:probes, Map.new(Ops.probe_names(), &{&1, :checking}))
     |> load()
     |> start_probes()
     |> put_flash(:info, "Refreshed.")}
  end

  def handle_event("run_job", %{"worker" => worker}, socket) do
    case Ops.run_scheduled_job(worker, actor: socket.assigns.current_admin) do
      {:ok, id} ->
        {:noreply, socket |> load() |> put_flash(:info, "Queued #{short(worker)} as job #{id}.")}

      {:error, error} ->
        {:noreply,
         put_flash(socket, :error, "Could not queue #{short(worker)}: #{message(error)}")}
    end
  end

  def handle_event("clear_office_cache", _params, socket) do
    case Ops.clear_office_cache(actor: socket.assigns.current_admin) do
      {:ok, machines} ->
        {:noreply,
         socket
         |> load()
         |> put_flash(:info, "Emptied the Office cache on #{machines} machine(s).")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not empty the cache: #{message(error)}")}
    end
  end

  def handle_async({:probe, name}, {:ok, result}, socket) do
    {:noreply, update(socket, :probes, &Map.put(&1, name, result))}
  end

  def handle_async({:probe, name}, {:exit, reason}, socket) do
    result = %{status: :error, detail: "probe crashed: #{inspect(reason)}", ms: nil}
    {:noreply, update(socket, :probes, &Map.put(&1, name, result))}
  end

  defp load(socket) do
    queues = Ops.queues()

    socket
    |> assign(:runtime, Ops.runtime())
    |> assign(:database, Ops.database())
    |> assign(:queues, queues)
    |> assign(:totals, totals(queues))
    |> assign(:failures, Ops.recent_failures(@failures))
    |> assign_schedule(Ops.schedule())
    |> assign(:office, Ops.office_cache())
    |> assign(:refreshed_at, DateTime.utc_now())
  end

  # A worker can be in the crontab more than once (at boot, and on a clock),
  # and running it now is the same act whichever row asks, so its first row
  # alone carries the button.
  defp assign_schedule(socket, schedule) do
    runnable =
      schedule
      |> Enum.with_index()
      |> Enum.uniq_by(fn {entry, _index} -> entry.worker end)
      |> MapSet.new(fn {_entry, index} -> index end)

    socket |> assign(:schedule, schedule) |> assign(:runnable, runnable)
  end

  defp start_probes(socket) do
    if connected?(socket),
      do: Enum.reduce(Ops.probe_names(), socket, &start_probe/2),
      else: socket
  end

  defp start_probe(name, socket),
    do: start_async(socket, {:probe, name}, fn -> Ops.probe(name) end)

  defp totals(queues) do
    %{
      waiting: count_in(queues, ~w(available scheduled)),
      failing: count_in(queues, ~w(retryable discarded))
    }
  end

  defp count_in(queues, states) do
    for row <- queues, state <- states, reduce: 0 do
      sum -> sum + Map.get(row.counts, state, 0)
    end
  end

  defp message(%{errors: [_ | _] = errors}), do: Enum.map_join(errors, "; ", &error_text/1)
  defp message(error) when is_exception(error), do: Exception.message(error)
  defp message(error), do: inspect(error)

  defp error_text(%{message: message}) when is_binary(message), do: message
  defp error_text(error), do: Exception.message(error)

  ## Presentation helpers used by the template

  @doc "The states a queue's row shows, in order, with their column headings."
  def queue_columns do
    [
      {"available", "Waiting"},
      {"scheduled", "Scheduled"},
      {"executing", "Running"},
      {"retryable", "Retrying"},
      {"discarded", "Discarded"},
      {"completed", "Done (7 days)"}
    ]
  end

  @doc "Oban Web's jobs list, filtered."
  def jobs_path(params \\ []) do
    query = params |> Enum.reject(fn {_key, value} -> is_nil(value) end) |> URI.encode_query()
    if query == "", do: "/admin/jobs/jobs", else: "/admin/jobs/jobs?" <> query
  end

  def job_path(id), do: "/admin/jobs/jobs/#{id}"

  @doc "A worker's module name without the app's namespace."
  def short(worker) when is_binary(worker), do: String.replace_prefix(worker, "LumenViae.", "")

  def format_time(nil), do: "-"
  def format_time(datetime), do: CentralTime.format_short(datetime)

  @doc "A byte count in the unit that reads best."
  def bytes(nil), do: "-"
  def bytes(n) when n >= 1_073_741_824, do: "#{Float.round(n / 1_073_741_824, 2)} GB"
  def bytes(n) when n >= 1_048_576, do: "#{Float.round(n / 1_048_576, 1)} MB"
  def bytes(n) when n >= 1024, do: "#{round(n / 1024)} KB"
  def bytes(n), do: "#{n} B"

  @doc "A duration in seconds as days, hours and minutes."
  def uptime(seconds) do
    days = div(seconds, 86_400)
    hours = div(rem(seconds, 86_400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    cond do
      days > 0 -> "#{days}d #{hours}h"
      hours > 0 -> "#{hours}h #{minutes}m"
      true -> "#{minutes}m"
    end
  end

  def percent(nil), do: "-"
  def percent(ratio), do: "#{Float.round(ratio * 100, 1)}%"

  @doc "How long the oldest waiting job has waited, or a dash."
  def waited(nil), do: "-"

  def waited(%DateTime{} = since) do
    seconds = max(DateTime.diff(DateTime.utc_now(), since), 0)
    if seconds < 60, do: "#{seconds}s", else: uptime(seconds)
  end

  def state_tone("completed"), do: "green"
  def state_tone(state) when state in ["retryable", "cancelled"], do: "amber"
  def state_tone("discarded"), do: "red"
  def state_tone(state) when state in ["executing", "available", "scheduled"], do: "navy"
  def state_tone(_other), do: "gray"

  def probe_label(:s3), do: "Audio bucket (S3)"
  def probe_label(:office_engine), do: "Divine Office engine"
  def probe_label(:geolocation), do: "Geolocation"
  def probe_label(:elevenlabs), do: "ElevenLabs"

  def probe_tone(:checking), do: "gray"
  def probe_tone(%{status: :ok}), do: "green"
  def probe_tone(%{status: :off}), do: "gray"
  def probe_tone(%{status: :error}), do: "red"

  def probe_status(:checking), do: "Checking"
  def probe_status(%{status: :ok}), do: "OK"
  def probe_status(%{status: :off}), do: "Off"
  def probe_status(%{status: :error}), do: "Failing"
end
