defmodule Mix.Tasks.LumenViae.RegenerateAudio do
  @shortdoc "Regenerates ElevenLabs audio for a meditation set or a meditation"

  @moduledoc """
  Regenerates narration audio for meditations that already have audio,
  replacing the existing S3 files in place (same keys), so sets imported
  before a pause-logic or voice change can be fixed without re-importing
  and without creating duplicate meditations.

      mix lumen_viae.regenerate_audio --set "Seven Sorrows of Mary"
      mix lumen_viae.regenerate_audio --id 42
      mix lumen_viae.regenerate_audio --set "Seven Sorrows of Mary" --dry-run

  ## Options

    * `--set NAME` - regenerate every meditation in the named set, in order
    * `--id ID` - regenerate a single meditation by id
    * `--dry-run` - list what would be regenerated (including the pause
      plan) without spending ElevenLabs credits or touching S3

  Exactly one of `--set` or `--id` is required. Meditations without an
  audio_url are skipped with a warning; regeneration never assigns new
  audio filenames.

  ## Environment

  Real runs require ELEVEN_LABS_API_KEY plus AWS credentials, as configured
  in runtime.exs. Run against the production database by exporting
  DATABASE_URL first, or regenerate on Fly with:

      fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.regenerate_audio(set: \\"Set Name\\")'"
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, argv, invalid} =
      OptionParser.parse(args, strict: [set: :string, id: :integer, dry_run: :boolean])

    cond do
      invalid != [] ->
        Mix.raise("Invalid options: #{inspect(invalid)}")

      argv != [] ->
        Mix.raise("Unexpected arguments: #{inspect(argv)}. " <> usage())

      true ->
        case target(opts) do
          {:ok, target} -> run_regeneration(target, opts)
          :error -> Mix.raise(usage())
        end
    end
  end

  defp usage do
    "Usage: mix lumen_viae.regenerate_audio (--set NAME | --id ID) [--dry-run]"
  end

  defp target(opts) do
    case {opts[:set], opts[:id]} do
      {set_name, nil} when is_binary(set_name) -> {:ok, {:set, set_name}}
      {nil, id} when is_integer(id) -> {:ok, {:meditation, id}}
      _ -> :error
    end
  end

  defp run_regeneration(target, opts) do
    progress = fn
      {:started, total} ->
        label = if opts[:dry_run], do: "Dry run: inspecting", else: "Regenerating"
        Mix.shell().info("#{label} audio for #{total} meditation(s)")

      {:item_finished, index, total, {status, message}} ->
        prefix =
          case status do
            :ok -> "OK   "
            :warning -> "WARN "
            :error -> "ERROR"
          end

        Mix.shell().info("#{prefix} [#{index}/#{total}] #{message}")
    end

    results =
      LumenViae.Meditations.AudioRegeneration.run(target,
        dry_run: opts[:dry_run],
        progress: progress
      )

    grouped = Enum.group_by(results, fn {status, _} -> status end)
    successes = Map.get(grouped, :ok, [])
    warnings = Map.get(grouped, :warning, [])
    errors = Map.get(grouped, :error, [])

    Mix.shell().info(
      "\n#{length(successes)} succeeded, #{length(warnings)} skipped or with warnings, " <>
        "#{length(errors)} failed"
    )

    if errors != [], do: exit({:shutdown, 1})
  end
end
