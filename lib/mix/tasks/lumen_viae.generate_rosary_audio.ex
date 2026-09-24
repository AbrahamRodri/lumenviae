defmodule Mix.Tasks.LumenViae.GenerateRosaryAudio do
  @shortdoc "Records the spoken Rosary's prayers, announcements and verses in every voice"

  @moduledoc """
  Records the spoken Rosary (`LumenViae.Rosary.PrayerAudio`) with
  ElevenLabs, once per narration voice, and uploads each clip to
  `voices/<slug>/rosary/<kind>/<name>-<hash>.mp3`. Clips already in the
  bucket are skipped, so an interrupted run resumes where it stopped.

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
    * `--concurrency N` - clips recorded at once (default 3)
    * `--dry-run` - no ElevenLabs calls and no uploads

  ## Environment

  Real runs require ELEVEN_LABS_API_KEY plus AWS credentials. Nothing is
  read from or written to the database, so this runs the same from a
  laptop (`source .env` first) as from production:

      fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.generate_rosary_audio()'"
  """

  use Mix.Task

  alias LumenViae.Curation.RosaryAudioGeneration
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

    # The audio clients only; the database is never touched.
    for app <- [:req, :ex_aws, :hackney], do: {:ok, _} = Application.ensure_all_started(app)
    Mix.Task.run("app.config")

    progress = fn
      {:started, total} ->
        label = if opts[:dry_run], do: "Dry run: inspecting", else: "Recording"
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
        concurrency: opts[:concurrency] || 3,
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

    verb = if opts[:dry_run], do: "would be recorded", else: "recorded"

    Mix.shell().info(
      "\n#{length(recorded)} #{verb} (#{characters} characters), " <>
        "#{length(skipped)} already recorded, #{length(errors)} failed"
    )

    if errors != [], do: exit({:shutdown, 1})
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
