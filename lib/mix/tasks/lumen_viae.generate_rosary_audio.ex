defmodule Mix.Tasks.LumenViae.GenerateRosaryAudio do
  @shortdoc "Records the spoken Rosary's prayers, announcements and verses in every voice"

  @moduledoc """
  Records the spoken Rosary (`LumenViae.Rosary.PrayerAudio`) with
  ElevenLabs, once per narration voice, and uploads each clip to
  `voices/<slug>/rosary/<kind>/<name>-<hash>.mp3`. Clips already in the
  bucket are skipped, so an interrupted run resumes where it stopped.

  Each missing clip is enqueued as a job
  (`LumenViae.Curation.Jobs.RecordRosaryClip`) on this machine's database,
  and this task's own node runs the jobs and waits for the last of them,
  printing each clip as it lands. A job interrupted with the task waits in
  the queue for the next run, and none pays ElevenLabs twice.

      mix lumen_viae.generate_rosary_audio --dry-run
      mix lumen_viae.generate_rosary_audio
      mix lumen_viae.generate_rosary_audio --voice female --kind prayers
      mix lumen_viae.generate_rosary_audio --kind announcements --force

  **Always dry-run first.** The dry run lists every clip a real run would
  record and totals the characters it would send to ElevenLabs.

  ## Options

    * `--voice SLUG` - only this voice (repeatable); default every voice
    * `--kind KIND` - `prayers`, `announcements` or `verses` (repeatable);
      default all three
    * `--force` - re-record clips that already exist
    * `--concurrency N` - clips recorded at once on this machine (default 3)
    * `--dry-run` - nothing enqueued, no ElevenLabs calls and no uploads

  ## Environment

  Real runs require ELEVEN_LABS_API_KEY plus AWS credentials. The clips
  themselves go to S3, never to a table, but the jobs are kept in the
  database of wherever the task runs: a laptop's dev database, which is
  how a reworded prayer is recorded from its branch before that branch is
  deployed (docs/SPOKEN_ROSARY.md). Production's equivalent enqueues on
  production's queue and lets the web app record:

      fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.generate_rosary_audio()'"

  A dry run needs no database.
  """

  use Mix.Task

  alias LumenViae.Curation.{AudioJobs, RosaryAudioGeneration}
  alias LumenViae.Rosary.PrayerAudio

  @impl Mix.Task
  def run(args) do
    {opts, argv, invalid} =
      OptionParser.parse(args,
        strict: [
          voice: :keep,
          kind: :keep,
          force: :boolean,
          concurrency: :integer,
          dry_run: :boolean
        ]
      )

    cond do
      invalid != [] -> Mix.raise("Invalid options: #{inspect(invalid)}")
      argv != [] -> Mix.raise("Unexpected arguments: #{inspect(argv)}")
      true -> generate(opts)
    end
  end

  defp generate(opts) do
    kinds = parse_kinds(Keyword.get_values(opts, :kind))

    # A dry run needs only the audio clients; a real run needs the app,
    # whose Oban runs the jobs it enqueues.
    if opts[:dry_run] do
      for app <- [:req, :ex_aws], do: {:ok, _} = Application.ensure_all_started(app)
      Mix.Task.run("app.config")
    else
      Mix.Task.run("app.start")
    end

    batch = AudioJobs.new_batch()
    unless opts[:dry_run], do: AudioJobs.subscribe(batch)

    progress = fn
      {:started, total} ->
        label = if opts[:dry_run], do: "Dry run: inspecting", else: "Checking"
        Mix.shell().info("#{label} #{total} clip(s)")

      {:item_finished, index, total, {status, message}} ->
        prefix =
          case status do
            :ok -> "OK   "
            :warning -> "SKIP "
            :error -> "ERROR"
          end

        Mix.shell().info("#{prefix} [#{index}/#{total}] #{message}")
    end

    results =
      RosaryAudioGeneration.run(
        voices: Keyword.get_values(opts, :voice),
        kinds: kinds,
        force: opts[:force],
        dry_run: opts[:dry_run],
        batch: batch,
        progress: progress
      )

    grouped = Enum.group_by(results, fn {status, _} -> status end)
    recorded = Map.get(grouped, :ok, [])
    skipped = Map.get(grouped, :warning, [])
    errors = Map.get(grouped, :error, [])

    characters =
      recorded
      |> Enum.map(fn {:ok, message} -> Regex.run(~r/ (\d+) characters/, message) end)
      |> Enum.reduce(0, fn [_, n], acc -> acc + String.to_integer(n) end)

    verb = if opts[:dry_run], do: "would be recorded", else: "queued"

    Mix.shell().info(
      "\n#{length(recorded)} #{verb} (#{characters} characters), " <>
        "#{length(skipped)} already recorded, #{length(errors)} failed"
    )

    recordings =
      if opts[:dry_run], do: %{failed: 0}, else: AudioJobs.wait_here(batch, opts[:concurrency])

    if errors != [] or recordings.failed > 0, do: exit({:shutdown, 1})
  end

  defp parse_kinds([]), do: nil

  defp parse_kinds(names) do
    kinds = PrayerAudio.kinds()

    Enum.map(names, fn name ->
      Map.get(kinds, name) ||
        Mix.raise(
          "Unknown --kind #{name}. Expected one of: #{kinds |> Map.keys() |> Enum.join(", ")}"
        )
    end)
  end
end
