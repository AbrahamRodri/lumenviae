defmodule Mix.Tasks.LumenViae.UploadChants do
  @shortdoc "Uploads the chant recordings and scores to S3 and writes their URLs"

  @moduledoc """
  Puts every chant recording and score page in the public assets bucket
  and writes each one's url, bytes and sha256 into
  `priv/library/chant_library.json` (`LumenViae.Curation.ChantUpload`).

      mix lumen_viae.upload_chants --source ../ios/app/Resources/Chants --dry-run
      mix lumen_viae.upload_chants --source ../ios/app/Resources/Chants \\
        --from ../ios/Tools/ContentExport/out/chant_library.json

  `--source` is the folder holding `<chant id>.m4a` and
  `Scores/<file>.lvscore`. `--from` is a new export from the iOS app, its
  URLs still null; without it the task re-reads the file it writes, which
  is how a changed recording is put in place. Files already in the bucket
  are not uploaded again, so a run is safe to repeat.

  **Dry-run first.** The dry run reads every file and lists what a run
  would upload, asks the bucket nothing and writes nothing.

  ## Environment

  A real run needs AWS credentials that may write the public assets
  bucket, such as the scoped `lumenviae-agent` profile's:

      eval "$(aws configure export-credentials --profile lumenviae-agent --format env)"

  The task runs without the app. An export with null URLs is read from
  `--from` and never copied into `priv/library/` by hand: the file there
  must compile, and this task is what makes the export fit to.
  """

  use Mix.Task

  alias LumenViae.Curation.ChantUpload

  @impl Mix.Task
  def run(args) do
    {opts, argv, invalid} =
      OptionParser.parse(args, strict: [source: :string, from: :string, dry_run: :boolean])

    cond do
      invalid != [] -> Mix.raise("Invalid options: #{inspect(invalid)}")
      argv != [] -> Mix.raise("Unexpected arguments: #{inspect(argv)}")
      is_nil(opts[:source]) -> Mix.raise("--source is required: the folder of chant recordings")
      true -> upload(opts)
    end
  end

  defp upload(opts) do
    for app <- [:req, :ex_aws], do: {:ok, _} = Application.ensure_all_started(app)
    Mix.Task.run("app.config")

    case ChantUpload.run(Keyword.take(opts, [:source, :from, :dry_run])) do
      {:ok, %{uploaded: uploaded, present: present, rewritten?: rewritten?}} ->
        verb = if opts[:dry_run], do: "would be uploaded", else: "uploaded"

        for key <- uploaded,
            do: Mix.shell().info("#{if opts[:dry_run], do: "WOULD", else: "OK   "} #{key}")

        Mix.shell().info(
          "\n#{length(uploaded)} #{verb}, #{length(present)} already in the bucket"
        )

        cond do
          not rewritten? -> Mix.shell().info("priv/library/chant_library.json is unchanged")
          opts[:dry_run] -> Mix.shell().info("priv/library/chant_library.json would be rewritten")
          true -> Mix.shell().info("priv/library/chant_library.json rewritten and dated now")
        end

      {:error, message} ->
        Mix.raise(message)
    end
  end
end
