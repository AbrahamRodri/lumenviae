defmodule LumenViae.Ops.Probes do
  @moduledoc """
  One question to each third party the app depends on, answered as
  `%{status: :ok | :error | :off, detail: String.t(), ms: integer}`.

    * `:s3` - one HEAD on a key that does not exist. The production
      credentials have no `s3:ListBucket`, so S3 answers that HEAD with 403
      rather than 404; `LumenViae.Storage.S3.audio_exists?/2` reads both as
      "absent", and either way the bucket was reached with credentials it
      accepted. Only a failure to ask at all is an error.
    * `:office_engine` - the current month's calendar, past the cache
      (`LumenViae.Office.ping/0`). It wakes a suspended engine.
    * `:geolocation` - the configuration only. A lookup would spend the
      provider's daily allowance to learn nothing about the app.
    * `:elevenlabs` - whether a key is configured, and nothing more: the
      app has no free call to make there.

  Every probe runs in a task with a timeout, so a third party that hangs
  costs `:timeout` milliseconds (default five seconds), never a stuck page.

  `config :lumen_viae, :ops_probe_answers, %{name => %{status:, detail:}}`
  answers a probe at once without asking anybody. The suite sets it for
  `:s3` and `:office_engine` (config/test.exs), so a screen that probes on
  mount renders the same way every run, however slow the machine; the
  probes' own tests clear it.
  """

  alias LumenViae.Services.Geolocation
  alias LumenViae.Storage.S3

  @names [:s3, :office_engine, :geolocation, :elevenlabs]
  @probe_key "ops/probe-#{:erlang.phash2(:lumen_viae)}"

  def names, do: @names

  def run(name, opts \\ []) when name in @names do
    case Application.get_env(:lumen_viae, :ops_probe_answers, %{}) do
      %{^name => answer} -> Map.put(answer, :ms, 0)
      _ask -> ask_in_time(name, opts)
    end
  end

  defp ask_in_time(name, opts) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    started = System.monotonic_time(:millisecond)
    task = Task.async(fn -> safely(fn -> ask(name) end) end)

    result =
      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, result} -> result
        nil -> %{status: :error, detail: "no answer within #{timeout} ms"}
      end

    Map.put(result, :ms, System.monotonic_time(:millisecond) - started)
  end

  defp ask(:s3) do
    bucket = Application.get_env(:lumen_viae, :aws_s3_bucket)

    case S3.audio_exists?(@probe_key) do
      {:ok, _exists} -> %{status: :ok, detail: "#{bucket} reachable"}
      {:error, reason} -> %{status: :error, detail: "#{bucket}: #{describe(reason)}"}
    end
  end

  defp ask(:office_engine) do
    base_url = Application.get_env(:lumen_viae, :office, []) |> Keyword.get(:base_url)

    case LumenViae.Office.ping() do
      :ok -> %{status: :ok, detail: "#{base_url} answered"}
      {:error, reason} -> %{status: :error, detail: "#{base_url}: #{describe(reason)}"}
    end
  end

  defp ask(:geolocation) do
    provider = Application.get_env(:lumen_viae, :geolocation, []) |> Keyword.get(:provider)

    if Geolocation.enabled?(),
      do: %{status: :ok, detail: "on, through #{provider}"},
      else: %{status: :off, detail: "switched off: completions are not placed"}
  end

  defp ask(:elevenlabs) do
    if Application.get_env(:lumen_viae, :eleven_labs_api_key) in [nil, ""],
      do: %{status: :off, detail: "no API key: narration cannot be recorded here"},
      else: %{status: :ok, detail: "API key set (not called)"}
  end

  defp safely(fun) do
    fun.()
  rescue
    exception -> %{status: :error, detail: Exception.message(exception)}
  end

  defp describe(reason) when is_binary(reason), do: reason
  defp describe(reason), do: inspect(reason, limit: 5, printable_limit: 120)
end
