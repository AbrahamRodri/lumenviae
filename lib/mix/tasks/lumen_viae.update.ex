defmodule Mix.Tasks.LumenViae.Update do
  @shortdoc "Replaces the text of existing meditations from a CSV and re-records them"

  @moduledoc """
  Edits meditations that already exist - a re-cut passage, a better title,
  a corrected source - keeping their ids, set memberships and audio
  filenames, and regenerating every voice's narration from the new text.
  See `LumenViae.Curation.CsvUpdate` for the CSV format.

      mix lumen_viae.update priv/repo/imports/fixes.csv --dry-run
      mix lumen_viae.update priv/repo/imports/fixes.csv

  ## Options

    * `--dry-run` - validate and describe each change; nothing is written
    * `--skip-audio` - write the text but leave the recordings alone
    * `--voice SLUG` - re-record only this voice (repeatable)

  Always dry-run first. On Fly:

      fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.update_csv(\\"/tmp/fixes.csv\\", dry_run: true)'"
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, argv, invalid} =
      OptionParser.parse(args, strict: [dry_run: :boolean, skip_audio: :boolean, voice: :keep])

    cond do
      invalid != [] ->
        Mix.raise("Invalid options: #{inspect(invalid)}")

      argv == [] ->
        Mix.raise(
          "Usage: mix lumen_viae.update PATH [--dry-run] [--skip-audio] [--voice SLUG]..."
        )

      true ->
        [path | _] = argv

        results =
          LumenViae.Curation.CsvUpdate.update_file(path,
            dry_run: opts[:dry_run],
            skip_audio: opts[:skip_audio],
            voices: Keyword.get_values(opts, :voice)
          )

        grouped = Enum.group_by(results, fn {status, _} -> status end)
        successes = Map.get(grouped, :ok, [])
        warnings = Map.get(grouped, :warning, [])
        errors = Map.get(grouped, :error, [])

        Enum.each(successes, fn {:ok, message} -> Mix.shell().info("OK    #{message}") end)
        Enum.each(warnings, fn {:warning, message} -> Mix.shell().info("WARN  #{message}") end)
        Enum.each(errors, fn {:error, message} -> Mix.shell().error("ERROR #{message}") end)

        Mix.shell().info(
          "\n#{length(successes)} succeeded, #{length(warnings)} with warnings, #{length(errors)} failed"
        )

        if errors != [], do: exit({:shutdown, 1})
    end
  end
end
