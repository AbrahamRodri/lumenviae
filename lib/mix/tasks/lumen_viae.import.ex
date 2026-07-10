defmodule Mix.Tasks.LumenViae.Import do
  @shortdoc "Imports meditations (and meditation sets) from a CSV file"

  @moduledoc """
  Imports meditations from a CSV file using the same engine as the admin
  upload UI (`LumenViae.Meditations.CsvImport`), so imports can be run from
  the command line or driven by Claude Code.

      mix lumen_viae.import priv/repo/emmerich_joyful_mysteries.csv

  ## Options

    * `--dry-run` - validate the file (mystery names, changesets, label
      vocabulary) without writing to the database or generating audio
    * `--skip-audio` - import rows but ignore audio_filename columns

  ## Environment

  Audio generation requires ELEVEN_LABS_API_KEY (and optional voice config)
  plus AWS credentials for the S3 upload, as configured in runtime.exs.
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
      OptionParser.parse(args, strict: [dry_run: :boolean, skip_audio: :boolean])

    cond do
      invalid != [] ->
        Mix.raise("Invalid options: #{inspect(invalid)}")

      argv == [] ->
        Mix.raise("Usage: mix lumen_viae.import PATH [--dry-run] [--skip-audio]")

      true ->
        [path | _] = argv
        run_import(path, opts)
    end
  end

  defp run_import(path, opts) do
    results = LumenViae.Meditations.CsvImport.import_file(path, opts)

    {successes, errors} = Enum.split_with(results, fn {status, _} -> status == :ok end)

    Enum.each(successes, fn {:ok, message} -> Mix.shell().info("OK    #{message}") end)
    Enum.each(errors, fn {:error, message} -> Mix.shell().error("ERROR #{message}") end)

    Mix.shell().info("\n#{length(successes)} succeeded, #{length(errors)} failed")

    if errors != [], do: exit({:shutdown, 1})
  end
end
