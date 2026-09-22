defmodule Mix.Tasks.LumenViae.Import do
  @shortdoc "Imports meditations (and meditation sets) from a CSV file"

  @moduledoc """
  Imports meditations from a CSV file using the same engine as the admin
  upload UI (`LumenViae.Curation.CsvImport`), so imports can be run from
  the command line or driven by Claude Code.

      mix lumen_viae.import priv/repo/emmerich_joyful_mysteries.csv

  ## Options

    * `--dry-run` - validate the file (mystery names, changesets, label
      vocabulary) without writing to the database or generating audio
    * `--skip-audio` - import rows but ignore audio_filename columns
    * `--voice SLUG` - record only this voice (repeatable); every configured
      voice by default, see `LumenViae.Rosary.Voices`

  ## Environment

  Audio generation requires ELEVEN_LABS_API_KEY plus AWS credentials for the S3 upload, as configured in runtime.exs.
  Run against the production database by exporting DATABASE_URL first, or
  import on Fly with:

      fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.import_csv(\"/tmp/file.csv\")'"

  See docs/CSV_IMPORT_GUIDE.md for the CSV format.
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
          "Usage: mix lumen_viae.import PATH [--dry-run] [--skip-audio] [--voice SLUG]..."
        )

      true ->
        [path | _] = argv
        run_import(path, opts)
    end
  end

  defp run_import(path, opts) do
    import_opts = [
      dry_run: opts[:dry_run],
      skip_audio: opts[:skip_audio],
      voices: Keyword.get_values(opts, :voice)
    ]

    results = LumenViae.Curation.CsvImport.import_file(path, import_opts)

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
