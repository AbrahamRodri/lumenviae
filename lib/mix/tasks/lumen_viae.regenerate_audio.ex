defmodule Mix.Tasks.LumenViae.RegenerateAudio do
  @shortdoc "Regenerates ElevenLabs audio for a meditation set, a meditation, or everything"

  @moduledoc """
  Regenerates narration audio for meditations that already have an audio
  filename, one recording per voice, replacing the S3 objects at
  `voices/<slug>/<filename>` and recording each as a narration. Sets
  imported before a pause-logic, model or voice change can be brought up to
  date without re-importing and without creating duplicate meditations.

  Each recording is a job (`LumenViae.Curation.Jobs.NarrateMeditation`).
  This task's own node runs them and waits until the last has finished.
  A recording whose object already matches what would be recorded (same
  text, voice, model and settings) is skipped without calling ElevenLabs,
  so running the same regeneration twice costs nothing the second time;
  `--force` records it again anyway.

      mix lumen_viae.regenerate_audio --set "Seven Sorrows of Mary"
      mix lumen_viae.regenerate_audio --id 42
      mix lumen_viae.regenerate_audio --all --voice female --only-missing
      mix lumen_viae.regenerate_audio --set "Seven Sorrows of Mary" --dry-run

  ## Options

    * `--set NAME` - regenerate every meditation in the named set, in order
    * `--id ID` - regenerate a single meditation by id
    * `--all` - regenerate every active meditation that has an audio file
    * `--voice SLUG` - only this voice (repeatable); default is every
      configured voice, see `LumenViae.Rosary.Voices`
    * `--only-missing` - skip (meditation, voice) pairs already recorded,
      so an interrupted run resumes without paying ElevenLabs twice
    * `--force` - record even when the object already matches: a
      deliberate second take, paid for again
    * `--concurrency N` - recordings at once on this machine (default 3)
    * `--dry-run` - list what would be regenerated (including the pause
      plan) without spending ElevenLabs credits or touching S3

  Exactly one of `--set`, `--id` or `--all` is required. Meditations
  without an audio_url are skipped with a warning; regeneration never
  assigns new audio filenames.

  ## Environment

  Real runs require ELEVEN_LABS_API_KEY plus AWS credentials, as configured
  in runtime.exs. The task runs against the local database
  (`DEV_DATABASE` picks a copy; `config/dev.exs` does not read
  `DATABASE_URL`). For production, regenerate on Fly with:

      fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.regenerate_audio(all: true, voices: [\\"female\\"])'"
  """

  use Mix.Task

  alias LumenViae.Curation.AudioJobs

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, argv, invalid} =
      OptionParser.parse(args,
        strict: [
          set: :string,
          id: :integer,
          all: :boolean,
          voice: :keep,
          only_missing: :boolean,
          force: :boolean,
          concurrency: :integer,
          dry_run: :boolean
        ]
      )

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
    "Usage: mix lumen_viae.regenerate_audio (--set NAME | --id ID | --all) " <>
      "[--voice SLUG]... [--only-missing] [--force] [--concurrency N] [--dry-run]"
  end

  defp target(opts) do
    case {opts[:set], opts[:id], opts[:all]} do
      {set_name, nil, nil} when is_binary(set_name) -> {:ok, {:set, set_name}}
      {nil, id, nil} when is_integer(id) -> {:ok, {:meditation, id}}
      {nil, nil, true} -> {:ok, :all}
      _ -> :error
    end
  end

  defp run_regeneration(target, opts) do
    batch = AudioJobs.new_batch()
    AudioJobs.subscribe(batch)

    progress = fn
      {:started, total} ->
        label = if opts[:dry_run], do: "Dry run: inspecting", else: "Queueing"
        Mix.shell().info("#{label} #{total} recording(s)")

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
      LumenViae.Curation.AudioRegeneration.run(target,
        voices: Keyword.get_values(opts, :voice),
        only_missing: opts[:only_missing],
        force: opts[:force],
        dry_run: opts[:dry_run],
        batch: batch,
        progress: progress,
        # An operator's shell already holds the database credentials, and
        # there is no signed-in admin to act as.
        authorize?: false
      )

    grouped = Enum.group_by(results, fn {status, _} -> status end)
    successes = Map.get(grouped, :ok, [])
    warnings = Map.get(grouped, :warning, [])
    errors = Map.get(grouped, :error, [])

    Mix.shell().info(
      "\n#{length(successes)} queued, #{length(warnings)} skipped or with warnings, " <>
        "#{length(errors)} failed"
    )

    recordings =
      if opts[:dry_run], do: %{failed: 0}, else: AudioJobs.wait_here(batch, opts[:concurrency])

    if errors != [] or recordings.failed > 0, do: exit({:shutdown, 1})
  end
end
